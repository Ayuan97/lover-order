package config

import (
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/viper"
)

// Config 应用配置根结构
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	Apple    AppleConfig    `mapstructure:"apple"`
	APNs     APNsConfig     `mapstructure:"apns"`
	Upload   UploadConfig   `mapstructure:"upload"`
	Log      LogConfig      `mapstructure:"log"`
	CORS     CORSConfig     `mapstructure:"cors"`
}

type ServerConfig struct {
	Port int    `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
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

// APNsConfig Apple 推送通知配置（可选；未填写 .p8 密钥时仅落库并发出干跑日志）
type APNsConfig struct {
	Enabled        bool   `mapstructure:"enabled"`
	TeamID         string `mapstructure:"team_id"`
	KeyID          string `mapstructure:"key_id"`
	BundleID       string `mapstructure:"bundle_id"`
	PrivateKeyPath string `mapstructure:"private_key_path"`
	Production     bool   `mapstructure:"production"`
}

type UploadConfig struct {
	MaxSize      int64     `mapstructure:"max_size"`
	AllowedTypes []string  `mapstructure:"allowed_types"`
	OSS          OSSConfig `mapstructure:"oss"`
}

type OSSConfig struct {
	Endpoint        string `mapstructure:"endpoint"`
	Bucket          string `mapstructure:"bucket"`
	AccessKeyID     string `mapstructure:"access_key_id"`
	AccessKeySecret string `mapstructure:"access_key_secret"`
	Prefix          string `mapstructure:"prefix"`
	PublicBaseURL   string `mapstructure:"public_base_url"`
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

// LoadConfig 加载配置文件（自动合并同目录 config.local.yaml 与 OSS 环境变量覆盖）
func LoadConfig(configPath string) *Config {
	viper.SetConfigFile(configPath)
	viper.SetConfigType("yaml")

	setDefaults()
	bindEnvOverrides()

	if err := viper.ReadInConfig(); err != nil {
		log.Fatalf("读取配置文件失败：%v", err)
	}

	localPath := filepath.Join(filepath.Dir(configPath), "config.local.yaml")
	if f, err := os.Open(localPath); err == nil {
		defer f.Close()
		if err := viper.MergeConfig(f); err != nil {
			log.Fatalf("合并本地配置文件失败：%v", err)
		}
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		log.Fatalf("解析配置失败：%v", err)
	}

	AppConfig = &cfg
	return &cfg
}

func bindEnvOverrides() {
	_ = viper.BindEnv("upload.oss.endpoint", "OSS_ENDPOINT")
	_ = viper.BindEnv("upload.oss.bucket", "OSS_BUCKET")
	_ = viper.BindEnv("upload.oss.access_key_id", "OSS_ACCESS_KEY_ID")
	_ = viper.BindEnv("upload.oss.access_key_secret", "OSS_ACCESS_KEY_SECRET")
	_ = viper.BindEnv("upload.oss.prefix", "OSS_PREFIX")
	_ = viper.BindEnv("upload.oss.public_base_url", "OSS_PUBLIC_BASE_URL")
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

	viper.SetDefault("apns.enabled", false)
	viper.SetDefault("apns.bundle_id", "com.loverorder.app")
	viper.SetDefault("apns.production", false)

	viper.SetDefault("upload.max_size", 10485760)
	viper.SetDefault("upload.oss.endpoint", "oss-cn-hangzhou.aliyuncs.com")
	viper.SetDefault("upload.oss.prefix", "uploads")

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
