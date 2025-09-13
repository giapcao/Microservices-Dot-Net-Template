namespace SharedLibrary.Authentication;

public record LoginRequest(string Email, string Password);

public record LoginResponse(
    string AccessToken, 
    string RefreshToken, 
    DateTime ExpiresAt, 
    UserInfo User
);

public record UserInfo(
    Guid UserId, 
    string Name, 
    string Email, 
    IEnumerable<string> Roles
);

public record RefreshTokenRequest(string RefreshToken);

public record TokenValidationResult(
    bool IsValid,
    Guid? UserId = null,
    string? Email = null,
    IEnumerable<string>? Roles = null
);
