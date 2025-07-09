package jwt

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"love-order-backend/internal/config"
)

// Claims JWT声明结构
type Claims struct {
	UserID   uint   `json:"user_id"`
	OpenID   string `json:"openid"`
	Role     string `json:"role"`
	FamilyID *uint  `json:"family_id"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT token
func GenerateToken(userID uint, openID, role string, familyID *uint) (string, error) {
	cfg := config.AppConfig
	if cfg == nil {
		return "", errors.New("config not initialized")
	}

	now := time.Now()
	claims := Claims{
		UserID:   userID,
		OpenID:   openID,
		Role:     role,
		FamilyID: familyID,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "love-order",
			Subject:   openID,
			Audience:  []string{"love-order-app"},
			ExpiresAt: jwt.NewNumericDate(now.Add(cfg.GetJWTExpireDuration())),
			NotBefore: jwt.NewNumericDate(now),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(cfg.JWT.Secret))
}

// ParseToken 解析JWT token
func ParseToken(tokenString string) (*Claims, error) {
	cfg := config.AppConfig
	if cfg == nil {
		return nil, errors.New("config not initialized")
	}

	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("invalid signing method")
		}
		return []byte(cfg.JWT.Secret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// RefreshToken 刷新token
func RefreshToken(tokenString string) (string, error) {
	claims, err := ParseToken(tokenString)
	if err != nil {
		return "", err
	}

	// 检查token是否即将过期（30分钟内）
	if time.Until(claims.ExpiresAt.Time) > 30*time.Minute {
		return "", errors.New("token not ready for refresh")
	}

	return GenerateToken(claims.UserID, claims.OpenID, claims.Role, claims.FamilyID)
}

// ValidateToken 验证token有效性
func ValidateToken(tokenString string) bool {
	_, err := ParseToken(tokenString)
	return err == nil
}
