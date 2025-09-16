using System;
using System.Collections.Generic;
using SharedLibrary.Common.ResponseModel;
using SharedLibrary.Abstractions.Messaging;
using Application.Common;
using AutoMapper;
using Domain.Entities;
using Domain.Repositories;
using MediatR;
using SharedLibrary.Common.Commands;

namespace Application.Guests.Commands
{
    public sealed record CreateGuestCommand(
        string Fullname,
        string Email
    ) : ICommand;
    internal sealed class CreateGuestCommandHandler : ICommandHandler<CreateGuestCommand>
    {
        private readonly IGuestRepository _guestRepository;
        private readonly IMapper _mapper;
        private readonly ISender _sender;

        public CreateGuestCommandHandler(IGuestRepository guestRepository, IMapper mapper, ISender sender)
        {
            _guestRepository = guestRepository;
            _mapper = mapper;
            _sender = sender;
        }
        public async Task<Result> Handle(CreateGuestCommand command, CancellationToken cancellationToken)
        {
            await _guestRepository.AddAsync(_mapper.Map<Guest>(command), cancellationToken);
            var saveResult = await _sender.Send(new SaveChangesCommand(), cancellationToken);
            if (saveResult.IsFailure)
            {
                return saveResult;
            }
            return Result.Success();
        }
    }
}