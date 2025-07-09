// 家庭管理相关API
import { request } from './request'
import { API_ENDPOINTS } from './config'

// 家庭信息接口
export interface FamilyInfo {
  id: number
  name: string
  invite_code: string
  avatar?: string
  description?: string
  created_by: number
  created_at: string
  updated_at: string
}

// 创建家庭参数
export interface CreateFamilyParams {
  name: string
  description?: string
  avatar?: string
}

// 加入家庭参数
export interface JoinFamilyParams {
  invite_code: string
}

// 家庭成员信息
export interface FamilyMember {
  id: number
  openid: string
  nickname: string
  avatar: string
  role: 'admin' | 'member' | 'guest'
  family_id: number
  is_active: boolean
  created_at: string
  updated_at: string
}

// 家庭统计信息
export interface FamilyStats {
  member_count: number
  guest_count: number
  recipe_count: number
  order_count: number
  total_amount: number
  monthly_orders: number
}

// 访客邀请参数
export interface CreateGuestInviteParams {
  note?: string
  expires_hours?: number // 邀请有效期（小时）
}

// 访客邀请信息
export interface GuestInvite {
  id: number
  invite_code: string
  family_id: number
  invited_by: number
  note?: string
  expires_at: string
  is_active: boolean
  used_count: number
  max_uses: number
  created_at: string
}

// 访客注册参数
export interface GuestRegisterParams {
  invite_code: string
  user_info?: {
    nickname: string
    avatar_url: string
    gender: number
  }
}

// 家庭API服务
export class FamilyService {
  // 创建家庭
  static async createFamily(params: CreateFamilyParams): Promise<FamilyInfo> {
    const response = await request.post(API_ENDPOINTS.FAMILY.CREATE, params)
    return response.data.data as FamilyInfo
  }

  // 获取家庭信息
  static async getFamilyInfo(): Promise<FamilyInfo> {
    const response = await request.get(API_ENDPOINTS.FAMILY.INFO)
    return response.data.data as FamilyInfo
  }

  // 更新家庭信息
  static async updateFamilyInfo(params: Partial<CreateFamilyParams>): Promise<FamilyInfo> {
    const response = await request.put(API_ENDPOINTS.FAMILY.UPDATE, params)
    return response.data.data as FamilyInfo
  }

  // 加入家庭
  static async joinFamily(params: JoinFamilyParams): Promise<FamilyInfo> {
    const response = await request.post(API_ENDPOINTS.FAMILY.JOIN, params)
    return response.data.data as FamilyInfo
  }

  // 退出家庭
  static async leaveFamily(): Promise<void> {
    await request.post(API_ENDPOINTS.FAMILY.LEAVE)
  }

  // 删除家庭
  static async deleteFamily(): Promise<void> {
    await request.delete(API_ENDPOINTS.FAMILY.DELETE)
  }

  // 获取家庭成员列表
  static async getFamilyMembers(includeGuests: boolean = false): Promise<FamilyMember[]> {
    const response = await request.get(API_ENDPOINTS.USER.FAMILY_MEMBERS, {
      include_guests: includeGuests
    })
    return response.data.data as FamilyMember[]
  }

  // 获取家庭统计信息
  static async getFamilyStats(): Promise<FamilyStats> {
    const response = await request.get(API_ENDPOINTS.FAMILY.STATS)
    return response.data.data as FamilyStats
  }

  // 检查用户是否有家庭
  static hasFamily(): boolean {
    try {
      const userInfo = uni.getStorageSync('user_info')
      return !!(userInfo && userInfo.family_id)
    } catch (error) {
      return false
    }
  }

  // 获取当前用户的家庭ID
  static getCurrentFamilyId(): number | null {
    try {
      const userInfo = uni.getStorageSync('user_info')
      return userInfo?.family_id || null
    } catch (error) {
      return null
    }
  }

  // 创建访客邀请
  static async createGuestInvite(params: CreateGuestInviteParams): Promise<GuestInvite> {
    const response = await request.post(API_ENDPOINTS.GUEST.INVITE, params)
    return response.data.data as GuestInvite
  }

  // 获取访客邀请列表
  static async getGuestInvites(): Promise<GuestInvite[]> {
    const response = await request.get(API_ENDPOINTS.GUEST.INVITATIONS)
    return response.data.data as GuestInvite[]
  }

  // 检查访客邀请码
  static async checkGuestInvite(inviteCode: string): Promise<any> {
    const response = await request.get(API_ENDPOINTS.GUEST.INVITE_CHECK, {
      invite_code: inviteCode
    })
    return response.data.data
  }

  // 访客注册
  static async guestRegister(params: GuestRegisterParams): Promise<any> {
    const response = await request.post(API_ENDPOINTS.GUEST.REGISTER, params)
    return response.data.data
  }

  // 生成分享链接
  static generateShareLink(inviteCode: string): string {
    // 这里可以根据实际部署的域名来生成
    const baseUrl = 'https://your-domain.com' // 替换为实际域名
    return `${baseUrl}/guest?invite=${inviteCode}`
  }

  // 生成分享文本
  static generateShareText(familyName: string, inviteCode: string): string {
    return `🏠 ${familyName} 邀请您品尝美味家常菜！\n\n📖 浏览精选菜谱\n🛒 在线点餐服务\n✨ 温馨家庭料理\n\n邀请码：${inviteCode}\n\n点击链接立即体验：${this.generateShareLink(inviteCode)}`
  }
}

// 导出默认服务
export default FamilyService
