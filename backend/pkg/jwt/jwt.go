package jwt

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"lover-order-backend/internal/config"
)

// TokenType 区分访问令牌和刷新令牌
type TokenType string

const (
	TokenTypeAccess  TokenType = "access"
	TokenTypeRefresh TokenType = "refresh"
)

// Claims 业务 JWT 声明
type Claims struct {
	UserID uint      `json:"user_id"`
	Type   TokenType `json:"type"`
	jwt.RegisteredClaims
}

// IssueAccess 签发访问令牌
func IssueAccess(userID uint) (string, error) {
	return issue(userID, TokenTypeAccess, config.AppConfig.AccessTokenDuration())
}

// IssueRefresh 签发刷新令牌
func IssueRefresh(userID uint) (string, error) {
	return issue(userID, TokenTypeRefresh, config.AppConfig.RefreshTokenDuration())
}

// Parse 解析并校验令牌
func Parse(tokenString string) (*Claims, error) {
	cfg := config.AppConfig
	if cfg == nil {
		return nil, errors.New("配置未初始化")
	}

	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("非法签名算法")
		}
		return []byte(cfg.JWT.Secret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("无效令牌")
	}
	return claims, nil
}

func issue(userID uint, typ TokenType, dur time.Duration) (string, error) {
	cfg := config.AppConfig
	if cfg == nil {
		return "", errors.New("配置未初始化")
	}
	now := time.Now()
	claims := Claims{
		UserID: userID,
		Type:   typ,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "lover-order",
			Subject:   "user",
			Audience:  []string{"lover-order-app"},
			ExpiresAt: jwt.NewNumericDate(now.Add(dur)),
			NotBefore: jwt.NewNumericDate(now),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(cfg.JWT.Secret))
}
