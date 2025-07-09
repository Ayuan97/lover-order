// 认证工具函数
import { AuthService } from '@/api/auth'

// JWT token解码工具
function decodeJWTPayload(token: string): any | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null

    // 解码base64url
    const payload = parts[1]
    // 处理base64url格式（替换字符并添加padding）
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/')
    const padded = base64 + '='.repeat((4 - base64.length % 4) % 4)

    return JSON.parse(atob(padded))
  } catch (error) {
    console.error('JWT解码失败:', error)
    return null
  }
}

// 需要登录的页面路径
const AUTH_REQUIRED_PAGES = [
  '/pages/index/index',
  '/pages/recipes/index',
  '/pages/orders/index',
  '/pages/profile/index'
]

// 检查是否需要登录
export function isAuthRequired(path: string): boolean {
  return AUTH_REQUIRED_PAGES.some(page => path.includes(page))
}

// 检查token是否已过期
function isTokenExpired(): boolean {
  try {
    const token = uni.getStorageSync('token')
    if (!token) return true

    const payload = decodeJWTPayload(token)
    if (!payload || !payload.exp) return true

    const exp = payload.exp * 1000 // 转换为毫秒
    const now = Date.now()

    return now >= exp
  } catch (error) {
    console.error('检查token过期状态失败:', error)
    return true
  }
}

// 检查登录状态
export function checkLoginStatus(): boolean {
  const hasToken = AuthService.isLoggedIn()
  if (!hasToken) return false

  // 检查token是否过期
  if (isTokenExpired()) {
    // Token已过期，清除本地存储
    AuthService.logout()
    return false
  }

  return true
}

// 跳转到登录页面
export function redirectToLogin(): void {
  uni.reLaunch({
    url: '/pages/login/index'
  })
}

// 检查token是否需要刷新（距离过期时间少于30分钟）
function isTokenNearExpiry(): boolean {
  try {
    const token = uni.getStorageSync('token')
    if (!token) return false

    const payload = decodeJWTPayload(token)
    if (!payload || !payload.exp) return false

    const exp = payload.exp * 1000 // 转换为毫秒
    const now = Date.now()
    const timeUntilExpiry = exp - now

    // 如果距离过期时间少于30分钟（1800000毫秒），则需要刷新
    return timeUntilExpiry <= 30 * 60 * 1000
  } catch (error) {
    console.error('检查token过期时间失败:', error)
    return false
  }
}

// 自动登录检查
export async function autoLoginCheck(): Promise<boolean> {
  try {
    // 如果已经有token，检查是否需要刷新
    if (checkLoginStatus()) {
      const token = uni.getStorageSync('token')
      const payload = decodeJWTPayload(token)

      if (payload && payload.exp) {
        const exp = payload.exp * 1000
        const now = Date.now()
        const timeUntilExpiry = exp - now
        const minutesUntilExpiry = Math.floor(timeUntilExpiry / (60 * 1000))

        console.log(`Token状态检查: 距离过期还有 ${minutesUntilExpiry} 分钟`)

        // 只有在token即将过期时才尝试刷新（距离过期少于30分钟）
        if (isTokenNearExpiry()) {
          console.log('Token即将过期，尝试刷新...')
          try {
            await AuthService.refreshToken()
            console.log('Token刷新成功')
            return true
          } catch (error: any) {
            console.error('Token刷新失败:', error)

            // 如果是"token not ready for refresh"错误，说明token还没到刷新时间
            if (error.message && error.message.includes('token not ready for refresh')) {
              console.log('Token尚未到达刷新时间，继续使用当前token')
              return true // 继续使用当前有效的token
            }

            // 其他错误，清除本地存储并尝试静默登录
            console.log('Token刷新失败，清除本地存储并尝试静默登录')
            AuthService.logout()
          }
        } else {
          // Token还有效且不需要刷新，直接返回成功
          console.log('Token仍然有效，无需刷新')
          return true
        }
      }
    }

    // 尝试静默登录
    console.log('尝试静默登录...')
    try {
      await AuthService.silentLogin()
      console.log('静默登录成功')
      return true
    } catch (error) {
      console.error('静默登录失败:', error)
      return false
    }
  } catch (error) {
    console.error('自动登录检查失败:', error)
    return false
  }
}

// 页面访问权限检查
export async function checkPageAccess(path: string): Promise<boolean> {
  // 如果不需要登录，直接允许访问
  if (!isAuthRequired(path)) {
    return true
  }
  
  // 检查登录状态
  if (checkLoginStatus()) {
    return true
  }
  
  // 尝试自动登录
  const autoLoginSuccess = await autoLoginCheck()
  if (autoLoginSuccess) {
    return true
  }
  
  // 需要手动登录
  redirectToLogin()
  return false
}

// 用户角色检查
export function checkUserRole(requiredRole: 'admin' | 'member' | 'guest'): boolean {
  const user = AuthService.getCurrentUser()
  if (!user) return false
  
  const roleLevel = {
    'guest': 1,
    'member': 2,
    'admin': 3
  }
  
  return roleLevel[user.role] >= roleLevel[requiredRole]
}

// 家庭成员检查
export function checkFamilyMember(): boolean {
  const user = AuthService.getCurrentUser()
  return !!(user && user.family_id)
}

// 管理员权限检查
export function checkAdminPermission(): boolean {
  return checkUserRole('admin')
}

// 登录状态监听器
class LoginStatusWatcher {
  private listeners: Array<(isLoggedIn: boolean) => void> = []
  
  // 添加监听器
  addListener(callback: (isLoggedIn: boolean) => void): void {
    this.listeners.push(callback)
  }
  
  // 移除监听器
  removeListener(callback: (isLoggedIn: boolean) => void): void {
    const index = this.listeners.indexOf(callback)
    if (index > -1) {
      this.listeners.splice(index, 1)
    }
  }
  
  // 通知所有监听器
  notify(isLoggedIn: boolean): void {
    this.listeners.forEach(callback => callback(isLoggedIn))
  }
}

export const loginStatusWatcher = new LoginStatusWatcher()

// 导出默认工具对象
export default {
  isAuthRequired,
  checkLoginStatus,
  redirectToLogin,
  autoLoginCheck,
  checkPageAccess,
  checkUserRole,
  checkFamilyMember,
  checkAdminPermission,
  loginStatusWatcher
}
