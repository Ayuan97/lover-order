package config

import (
	"log"
	"time"

	"github.com/spf13/viper"
)

// Config 应用配置根结构
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	Apple    AppleConfig    `mapstructure:"apple"`
	Upload   UploadConfig   `mapstructure:"upload"`
	Log      LogConfig      `mapstructure:"log"`
	CORS     CORSConfig     `mapstructure:"cors"`
}

type ServerConfig struct {
	Port int    `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
	// DevCode 非空时 dev 登录必须携带匹配暗号 防止公网部署后凭昵称顶号
	DevCode string `mapstructure:"dev_code"`
}

type DatabaseConfig struct {
	Host            string `mapstructure:"host"`
	Port            int    `mapstructure:"port"`
	Username        string `mapstructure:"username"`
	Password        string `mapstructure:"password"`
	Database        string `mapstructure:"database"`
	Charset         string `mapstructure:"charset"`
	ParseTime       bool   `mapstructure:"parse_time"`
	Loc             string `mapstructure:"loc"`
	MaxIdleConns    int    `mapstructure:"max_idle_conns"`
	MaxOpenConns    int    `mapstructure:"max_open_conns"`
	ConnMaxLifetime int    `mapstructure:"conn_max_lifetime"`
}

type JWTConfig struct {
	Secret             string `mapstructure:"secret"`
	ExpireHours        int    `mapstructure:"expire_hours"`
	RefreshExpireHours int    `mapstructure:"refresh_expire_hours"`
}

// AppleConfig Apple Sign In 配置
type AppleConfig struct {
	TeamID         string `mapstructure:"team_id"`
	ClientID       string `mapstructure:"client_id"`
	KeyID          string `mapstructure:"key_id"`
	PrivateKeyPath string `mapstructure:"private_key_path"`
	JWKSURL        string `mapstructure:"jwks_url"`
	Issuer         string `mapstructure:"issuer"`
}

type UploadConfig struct {
	Path         string   `mapstructure:"path"`
	MaxSize      int64    `mapstructure:"max_size"`
	AllowedTypes []string `mapstructure:"allowed_types"`
}

type LogConfig struct {
	Level      string `mapstructure:"level"`
	File       string `mapstructure:"file"`
	MaxSize    int    `mapstructure:"max_size"`
	MaxBackups int    `mapstructure:"max_backups"`
	MaxAge     int    `mapstructure:"max_age"`
}

type CORSConfig struct {
	AllowOrigins []string `mapstructure:"allow_origins"`
	AllowMethods []string `mapstructure:"allow_methods"`
	AllowHeaders []string `mapstructure:"allow_headers"`
}

// AppConfig 全局配置实例
var AppConfig *Config

// LoadConfig 加载配置文件
func LoadConfig(configPath string) *Config {
	viper.SetConfigFile(configPath)
	viper.SetConfigType("yaml")

	setDefaults()

	if err := viper.ReadInConfig(); err != nil {
		log.Fatalf("读取配置文件失败：%v", err)
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		log.Fatalf("解析配置失败：%v", err)
	}

	AppConfig = &cfg
	return &cfg
}

// setDefaults 设置默认值
func setDefaults() {
	viper.SetDefault("server.port", 8081)
	viper.SetDefault("server.mode", "debug")

	viper.SetDefault("database.host", "127.0.0.1")
	viper.SetDefault("database.port", 3306)
	viper.SetDefault("database.charset", "utf8mb4")
	viper.SetDefault("database.parse_time", true)
	viper.SetDefault("database.loc", "Local")
	viper.SetDefault("database.max_idle_conns", 10)
	viper.SetDefault("database.max_open_conns", 100)
	viper.SetDefault("database.conn_max_lifetime", 3600)

	viper.SetDefault("jwt.expire_hours", 168)
	viper.SetDefault("jwt.refresh_expire_hours", 720)

	viper.SetDefault("apple.jwks_url", "https://appleid.apple.com/auth/keys")
	viper.SetDefault("apple.issuer", "https://appleid.apple.com")

	viper.SetDefault("upload.path", "./uploads")
	viper.SetDefault("upload.max_size", 10485760)

	viper.SetDefault("log.level", "info")
}

// AccessTokenDuration 访问令牌有效期
func (c *Config) AccessTokenDuration() time.Duration {
	return time.Duration(c.JWT.ExpireHours) * time.Hour
}

// RefreshTokenDuration 刷新令牌有效期
func (c *Config) RefreshTokenDuration() time.Duration {
	return time.Duration(c.JWT.RefreshExpireHours) * time.Hour
}
