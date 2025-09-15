using Domain.Entities;
using Domain.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;
using SharedLibrary.Authentication;
using SharedLibrary.Common.ResponseModel;
using Application.Abstractions.UnitOfWork;
using SharedLibrary.Extensions;

namespace Application.Users.Commands;

public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, Result<LoginResponse>>
{
    private readonly IUserRepository _userRepository;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IUnitOfWork _unitOfWork;

    public RefreshTokenCommandHandler(
        IUserRepository userRepository,
        IJwtTokenService jwtTokenService,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _jwtTokenService = jwtTokenService;
        _unitOfWork = unitOfWork;
    }

    public async Task<Result<LoginResponse>> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        // Find user by refresh token
        var user = await _userRepository.GetAll()
            .Include(u => u.UserRoles)
            .ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.RefreshToken == request.RefreshToken, cancellationToken);

        if (user == null || user.RefreshTokenExpiry < DateTimeExtensions.PostgreSqlUtcNow)
        {
            return Result.Failure<LoginResponse>(new Error("Auth.InvalidRefreshToken", "Invalid or expired refresh token"));
        }

        // Get user roles
        var roles = user.UserRoles.Select(ur => ur.Role.RoleName).ToList();

        // Generate new tokens
        var accessToken = _jwtTokenService.GenerateToken(user.UserId, user.Email, roles);
        var newRefreshToken = _jwtTokenService.GenerateRefreshToken();

        // Update user with new refresh token
        user.RefreshToken = newRefreshToken;
        user.RefreshTokenExpiry = DateTimeExtensions.PostgreSqlUtcNow.AddDays(7);

        _userRepository.Update(user);

        var response = new LoginResponse(
            AccessToken: accessToken,
            RefreshToken: newRefreshToken,
            ExpiresAt: DateTime.Now.AddMinutes(60),
            User: new UserInfo(user.UserId, user.Name, user.Email, roles)
        );

        return Result.Success(response);
    }
}
