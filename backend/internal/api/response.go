package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// 统一响应码
const (
	CodeOK            = 0
	CodeBadRequest    = 400
	CodeUnauthorized  = 401
	CodeForbidden     = 403
	CodeNotFound      = 404
	CodeConflict      = 409
	CodeInternalError = 500
)

// Resp 通用响应体
type Resp struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// OK 200 响应
func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Resp{Code: CodeOK, Message: "ok", Data: data})
}

// Fail 业务错误响应 不强制 HTTP 状态码
func Fail(c *gin.Context, code int, msg string) {
	httpCode := http.StatusOK
	switch code {
	case CodeBadRequest:
		httpCode = http.StatusBadRequest
	case CodeUnauthorized:
		httpCode = http.StatusUnauthorized
	case CodeForbidden:
		httpCode = http.StatusForbidden
	case CodeNotFound:
		httpCode = http.StatusNotFound
	case CodeConflict:
		httpCode = http.StatusConflict
	case CodeInternalError:
		httpCode = http.StatusInternalServerError
	}
	c.JSON(httpCode, Resp{Code: code, Message: msg})
}
