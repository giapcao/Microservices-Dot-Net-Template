using System;
using System.Collections.Generic;
using SharedLibrary.Common.ResponseModel;
using Application.Abstractions.Messaging;
using Application.Abstractions.UnitOfWork;
using Application.Common;
using AutoMapper;
using Domain.Entities;
using Domain.Repositories;
using MassTransit;
using MediatR;
using SharedLibrary.Contracts.UserCreating;
using SharedLibrary.Authentication;
using SharedLibrary.Extensions;

namespace Application.Users.Commands
{
    public sealed record CreateUserCommand(
        string Name,
        string Email,
        string Password
    ) : ICommand;
    internal sealed class CreateUserCommandHandler : ICommandHandler<CreateUserCommand>
    {
        private readonly IUserRepository _userRepository;
        private readonly IRoleRepository _roleRepository;
        private readonly IUserRoleRepository _userRoleRepository;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IMapper _mapper;
        private readonly IPasswordHasher _passwordHasher;
        private readonly IPublishEndpoint _publishEndpoint;

        public CreateUserCommandHandler(IUserRepository userRepository, IRoleRepository roleRepository, IUserRoleRepository userRoleRepository, IMapper mapper, IUnitOfWork unitOfWork, IPasswordHasher passwordHasher, IPublishEndpoint publishEndpoint)
        {
            _userRepository = userRepository;
            _roleRepository = roleRepository;
            _userRoleRepository = userRoleRepository;
            _mapper = mapper;
            _unitOfWork = unitOfWork;
            _passwordHasher = passwordHasher;
            _publishEndpoint = publishEndpoint;
        }
        public async Task<Result> Handle(CreateUserCommand command, CancellationToken cancellationToken)
        {
            var user = _mapper.Map<User>(command);
            user.PasswordHash = _passwordHasher.HashPassword(command.Password);
            user.CreatedAt = DateTimeExtensions.PostgreSqlUtcNow;
            
            // Find or create default "User" role
            var userRole = await _roleRepository.GetByNameAsync("User", cancellationToken);
            if (userRole == null)
            {
                userRole = new Role
                {
                    RoleId = Guid.NewGuid(),
                    RoleName = "User",
                    CreatedAt = DateTimeExtensions.PostgreSqlUtcNow
                };
                await _roleRepository.AddAsync(userRole, cancellationToken);
            }
            
            await _userRepository.AddAsync(user, cancellationToken);
            
            // Assign default role to user
            var userRoleAssignment = new UserRole
            {
                UserId = user.UserId,
                RoleId = userRole.RoleId
            };
            
            await _userRoleRepository.AddAsync(userRoleAssignment, cancellationToken);
            
            await _publishEndpoint.Publish(new UserCreatingSagaStart{
                CorrelationId= Guid.NewGuid(),
                Name = command.Name,
                Email = command.Email
            }, cancellationToken);
            return Result.Success();
        }
    }
}