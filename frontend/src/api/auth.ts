// 认证相关API
import { request } from './request'
import { API_ENDPOINTS } from './config'

// 用户信息接口
export interface UserInfo {
  id: number
  openid: string
  unionid?: string
  nickname: string
  avatar: string
  gender: number
  role: 'admin' | 'member' | 'guest'
  family_id?: number
  is_active: boolean
  created_at: string
  updated_at: string
}

// 微信登录参数
export interface WechatLoginParams {
  code: string
  user_info?: {
    nickname: string
    avatar_url: string
    gender: number
  }
}

// 登录响应
export interface LoginResponse {
  token: string
  user: UserInfo
}

// 认证API服务
export class AuthService {
  // 微信登录
  static async wechatLogin(params: WechatLoginParams): Promise<LoginResponse> {
    const response = await request.post(API_ENDPOINTS.AUTH.WECHAT_LOGIN, params)

    // 添加调试日志
    console.log('完整响应:', response)
    console.log('登录响应数据:', response.data)

    // 获取实际的登录数据（后端返回的data字段）
    const loginData = response.data.data as LoginResponse
    console.log('实际登录数据:', loginData)

    // 登录成功后保存token
    if (loginData.token) {
      request.setAuthToken(loginData.token)

      // 保存用户信息
      console.log('保存用户信息:', loginData.user)
      uni.setStorageSync('user_info', loginData.user)
      // 暂时使用token作为refresh_token（后续可以改进）
      uni.setStorageSync('refresh_token', loginData.token)
    }

    return loginData
  }

  // 刷新token
  static async refreshToken(): Promise<LoginResponse> {
    const refreshToken = uni.getStorageSync('refresh_token')
    if (!refreshToken) {
      throw new Error('没有refresh token')
    }

    console.log('发送token刷新请求...')

    try {
      const response = await request.post(API_ENDPOINTS.AUTH.REFRESH_TOKEN, {
        token: refreshToken
      })

      console.log('Token刷新响应:', response)

      // 获取实际的数据
      const tokenData = response.data.data as { token: string }

      // 更新token
      if (tokenData.token) {
        request.setAuthToken(tokenData.token)
        // 暂时使用token作为refresh_token（后续可以改进）
        uni.setStorageSync('refresh_token', tokenData.token)
        console.log('Token更新成功')
      }

      // 返回简化的响应（只包含token）
      const currentUser = this.getCurrentUser()
      return {
        token: tokenData.token,
        user: currentUser || {
          id: 0,
          openid: '',
          nickname: '',
          avatar: '',
          gender: 0,
          role: 'member' as const,
          is_active: true,
          created_at: '',
          updated_at: ''
        }
      }
    } catch (error: any) {
      console.error('Token刷新请求失败:', error)

      // 如果是"token not ready for refresh"错误，提供更友好的错误信息
      if (error.data && error.data.error && error.data.error.includes('token not ready for refresh')) {
        throw new Error('token not ready for refresh')
      }

      // 检查其他可能的错误格式
      if (error.message && error.message.includes('token not ready for refresh')) {
        throw new Error('token not ready for refresh')
      }

      throw error
    }
  }

  // 登出
  static async logout(): Promise<void> {
    try {
      await request.post(API_ENDPOINTS.AUTH.LOGOUT)
    } catch (error) {
      console.error('登出请求失败:', error)
    } finally {
      // 清除本地存储
      request.clearAuthToken()
      uni.removeStorageSync('user_info')
      uni.removeStorageSync('refresh_token')
    }
  }

  // 获取用户信息
  static async getUserProfile(): Promise<UserInfo> {
    const response = await request.get(API_ENDPOINTS.USER.PROFILE)
    return response.data.data as UserInfo
  }

  // 更新用户信息
  static async updateUserProfile(params: Partial<UserInfo>): Promise<UserInfo> {
    const response = await request.put(API_ENDPOINTS.USER.PROFILE, params)

    // 获取实际的用户数据
    const userData = response.data.data as UserInfo

    // 更新本地存储的用户信息
    uni.setStorageSync('user_info', userData)

    return userData
  }

  // 检查登录状态（仅检查本地存储，不验证token有效性）
  static isLoggedIn(): boolean {
    const token = uni.getStorageSync('token')
    const userInfo = uni.getStorageSync('user_info')
    return !!(token && userInfo)
  }

  // 获取当前用户信息
  static getCurrentUser(): UserInfo | null {
    try {
      return uni.getStorageSync('user_info')
    } catch (error) {
      return null
    }
  }

  // 微信登录（小程序专用）- 按照官方推荐流程
  static async wechatMiniLogin(): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      // 1. 获取微信登录code（官方推荐的第一步）
      uni.login({
        provider: 'weixin',
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error('获取微信登录code失败')
            }

            // 2. 调用后端登录接口（只传code，不传用户信息）
            const result = await this.wechatLogin({
              code: loginRes.code
            })

            resolve(result)
          } catch (error) {
            reject(error)
          }
        },
        fail: (error) => {
          reject(new Error('微信登录失败: ' + error.errMsg))
        }
      })
    })
  }

  // 获取用户信息（独立的步骤，可选）
  static async getUserInfo(): Promise<any> {
    return new Promise((resolve, reject) => {
      uni.getUserProfile({
        desc: '用于完善用户资料',
        success: (userRes: any) => {
          resolve({
            nickname: userRes.userInfo.nickName,
            avatar_url: userRes.userInfo.avatarUrl,
            gender: userRes.userInfo.gender
          })
        },
        fail: (error) => {
          reject(new Error('获取用户信息失败: ' + error.errMsg))
        }
      })
    })
  }

  // 完整登录流程（登录 + 获取用户信息）
  static async wechatMiniLoginWithUserInfo(): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      // 1. 先获取用户信息（必须在用户点击事件中直接调用）
      uni.getUserProfile({
        desc: '用于完善用户资料',
        success: async (userRes: any) => {
          try {
            // 2. 获取微信登录code
            uni.login({
              provider: 'weixin',
              success: async (loginRes) => {
                try {
                  if (!loginRes.code) {
                    throw new Error('获取微信登录code失败')
                  }

                  // 3. 调用后端登录接口（包含用户信息）
                  const result = await this.wechatLogin({
                    code: loginRes.code,
                    user_info: {
                      nickname: userRes.userInfo.nickName,
                      avatar_url: userRes.userInfo.avatarUrl,
                      gender: userRes.userInfo.gender
                    }
                  })

                  resolve(result)
                } catch (error) {
                  reject(error)
                }
              },
              fail: (error) => {
                reject(new Error('微信登录失败: ' + error.errMsg))
              }
            })
          } catch (error) {
            reject(error)
          }
        },
        fail: (error) => {
          reject(new Error('获取用户信息失败: ' + error.errMsg))
        }
      })
    })
  }

  // 简化版微信登录（不获取用户详细信息）
  static async wechatMiniLoginSimple(): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      // 只获取登录code，不获取用户详细信息
      uni.login({
        provider: 'weixin',
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error('获取微信登录code失败')
            }

            // 调用后端登录接口（不传用户信息）
            const result = await this.wechatLogin({
              code: loginRes.code
            })

            resolve(result)
          } catch (error) {
            reject(error)
          }
        },
        fail: (error) => {
          reject(new Error('微信登录失败: ' + error.errMsg))
        }
      })
    })
  }

  // 静默登录（使用已有的code）
  static async silentLogin(): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      uni.login({
        provider: 'weixin',
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error('获取微信登录code失败')
            }

            // 只使用code登录，不获取用户信息
            const result = await this.wechatLogin({
              code: loginRes.code
            })
            
            resolve(result)
          } catch (error) {
            reject(error)
          }
        },
        fail: (error) => {
          reject(new Error('微信登录失败: ' + error.errMsg))
        }
      })
    })
  }
}

// 导出默认服务
export default AuthService
