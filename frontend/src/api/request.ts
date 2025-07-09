// HTTP请求封装
import { API_CONFIG, HTTP_STATUS, ERROR_MESSAGES } from './config'

// 请求接口
interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  data?: any
  headers?: Record<string, string>
  timeout?: number
}

// 响应接口
interface ApiResponse<T = any> {
  code: number
  message: string
  data: T
  success: boolean
}

// 错误接口
interface ApiError {
  code: number
  message: string
  details?: any
}

class RequestService {
  private baseURL: string
  private timeout: number
  private defaultHeaders: Record<string, string>

  constructor() {
    this.baseURL = API_CONFIG.BASE_URL
    this.timeout = API_CONFIG.TIMEOUT
    this.defaultHeaders = API_CONFIG.HEADERS
  }

  // 获取存储的token
  private getToken(): string | null {
    try {
      return uni.getStorageSync('token')
    } catch (error) {
      console.error('获取token失败:', error)
      return null
    }
  }

  // 设置token
  private setToken(token: string): void {
    try {
      uni.setStorageSync('token', token)
    } catch (error) {
      console.error('设置token失败:', error)
    }
  }

  // 清除token
  private clearToken(): void {
    try {
      uni.removeStorageSync('token')
    } catch (error) {
      console.error('清除token失败:', error)
    }
  }

  // 处理请求头
  private getHeaders(customHeaders?: Record<string, string>): Record<string, string> {
    const headers = { ...this.defaultHeaders, ...customHeaders }
    
    const token = this.getToken()
    if (token) {
      headers['Authorization'] = `Bearer ${token}`
    }
    
    return headers
  }

  // 处理错误
  private handleError(error: any): ApiError {
    console.error('API请求错误:', error)
    
    if (error.statusCode) {
      switch (error.statusCode) {
        case HTTP_STATUS.UNAUTHORIZED:
          this.clearToken()
          return {
            code: HTTP_STATUS.UNAUTHORIZED,
            message: ERROR_MESSAGES.UNAUTHORIZED
          }
        case HTTP_STATUS.FORBIDDEN:
          return {
            code: HTTP_STATUS.FORBIDDEN,
            message: ERROR_MESSAGES.FORBIDDEN
          }
        case HTTP_STATUS.NOT_FOUND:
          return {
            code: HTTP_STATUS.NOT_FOUND,
            message: ERROR_MESSAGES.NOT_FOUND
          }
        case HTTP_STATUS.INTERNAL_SERVER_ERROR:
          return {
            code: HTTP_STATUS.INTERNAL_SERVER_ERROR,
            message: ERROR_MESSAGES.SERVER_ERROR
          }
        default:
          return {
            code: error.statusCode,
            message: error.data?.message || ERROR_MESSAGES.UNKNOWN_ERROR
          }
      }
    }
    
    // 网络错误或超时
    if (error.errMsg) {
      if (error.errMsg.includes('timeout')) {
        return {
          code: -1,
          message: ERROR_MESSAGES.TIMEOUT_ERROR
        }
      } else if (error.errMsg.includes('fail')) {
        return {
          code: -2,
          message: ERROR_MESSAGES.NETWORK_ERROR
        }
      }
    }
    
    return {
      code: -999,
      message: ERROR_MESSAGES.UNKNOWN_ERROR,
      details: error
    }
  }

  // 发送请求
  async request<T = any>(url: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    const {
      method = 'GET',
      data,
      headers: customHeaders,
      timeout = this.timeout
    } = options

    const fullUrl = url.startsWith('http') ? url : `${this.baseURL}${url}`
    const headers = this.getHeaders(customHeaders)

    return new Promise((resolve, reject) => {
      uni.request({
        url: fullUrl,
        method,
        data,
        header: headers,
        timeout,
        success: (response: any) => {
          const { statusCode, data: responseData } = response
          
          if (statusCode >= 200 && statusCode < 300) {
            // 成功响应
            resolve({
              code: statusCode,
              message: 'success',
              data: responseData,
              success: true
            })
          } else {
            // HTTP错误状态码
            const error = this.handleError({ statusCode, data: responseData })
            reject(error)
          }
        },
        fail: (error: any) => {
          const apiError = this.handleError(error)
          reject(apiError)
        }
      })
    })
  }

  // GET请求
  async get<T = any>(url: string, params?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    let fullUrl = url
    if (params) {
      const queryString = Object.keys(params)
        .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
        .join('&')
      fullUrl += `?${queryString}`
    }
    
    return this.request<T>(fullUrl, { method: 'GET', headers })
  }

  // POST请求
  async post<T = any>(url: string, data?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>(url, { method: 'POST', data, headers })
  }

  // PUT请求
  async put<T = any>(url: string, data?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>(url, { method: 'PUT', data, headers })
  }

  // DELETE请求
  async delete<T = any>(url: string, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>(url, { method: 'DELETE', headers })
  }

  // 设置基础URL
  setBaseURL(baseURL: string): void {
    this.baseURL = baseURL
  }

  // 设置超时时间
  setTimeout(timeout: number): void {
    this.timeout = timeout
  }

  // 登录成功后设置token
  setAuthToken(token: string): void {
    this.setToken(token)
  }

  // 登出时清除token
  clearAuthToken(): void {
    this.clearToken()
  }
}

// 创建请求实例
export const request = new RequestService()

// 导出类型
export type { RequestOptions, ApiResponse, ApiError }
