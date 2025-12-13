import { request } from './request'

// 订单状态类型
export type OrderStatus = 'pending' | 'confirmed' | 'cooking' | 'completed' | 'cancelled'

// 订单接口类型定义
export interface OrderItem {
  id?: number
  order_id?: number
  recipe_id: number
  recipe_name: string
  recipe_image?: string
  recipe_description?: string
  quantity: number
  unit_price: number
  total_price: number
  note?: string
}

export interface OrderReview {
  id?: number
  order_id: number
  user_id: number
  rating: number  // 1-5星评分
  comment?: string  // 评价留言
  emoji?: string  // 表情反馈
  created_at?: string
}

export interface Order {
  id: number
  order_no: string
  user_id: number
  family_id: number
  total_amount: number
  item_count: number
  status: OrderStatus
  meal_time?: string
  note?: string
  is_guest_order: boolean
  confirmed_by?: number
  confirmed_at?: string
  completed_at?: string
  cancelled_at?: string
  cancel_reason?: string
  created_at: string
  updated_at: string

  // 关联数据
  user?: {
    id: number
    nickname: string
    avatar?: string
  }
  items?: OrderItem[]
  confirmed_by_user?: {
    id: number
    nickname: string
  }
  review?: OrderReview  // 订单评价
}

// 请求参数类型
export interface CreateOrderRequest {
  items: Array<{
    recipe_id: number
    quantity: number
    note?: string
  }>
  meal_time?: string
  note?: string
}

export interface OrderListRequest {
  page?: number
  size?: number
  status?: OrderStatus
  start_date?: string
  end_date?: string
  user_id?: number
  sort_by?: 'created_at' | 'meal_time' | 'total_amount'
  sort_order?: 'asc' | 'desc'
}

export interface OrderListResponse {
  list: Order[]
  total: number
  page: number
  size: number
}

export interface OrderStats {
  total_orders: number
  total_amount: number
  average_amount: number
  status_stats: Array<{
    status: string
    count: number
  }>
  popular_recipes: Array<{
    recipe_id: number
    recipe_name: string
    order_count: number
  }>
  daily_trend: Array<{
    date: string
    count: number
  }>
  period_days: number
}

export interface UserOrderSummary {
  total_orders: number
  monthly_orders: number
  favorite_count: number
  recent_orders: Order[]
  favorite_recipes: Array<{
    recipe_id: number
    recipe_name: string
    order_count: number
  }>
}

// 订单回复接口
export interface OrderReply {
  id: number
  order_id: number
  user_id: number
  content: string
  created_at: string
  user?: {
    id: number
    nickname: string
    avatar?: string
  }
}

// 订单服务
export const OrderService = {
  /**
   * 创建订单
   */
  async createOrder(data: CreateOrderRequest): Promise<Order> {
    const response = await request.post('/orders', data)
    // 处理可能的嵌套data结构
    return response.data.data || response.data
  },

  /**
   * 获取订单列表
   */
  async getOrderList(params: OrderListRequest = {}): Promise<OrderListResponse> {
    const response = await request.get('/orders', params)
    // 处理可能的嵌套data结构
    const data = response.data.data || response.data
    return {
      list: data.list || [],
      total: data.total || 0,
      page: data.page || 1,
      size: data.size || params.size || 20
    }
  },

  /**
   * 获取订单详情
   */
  async getOrderDetail(orderId: number): Promise<Order> {
    const response = await request.get(`/orders/${orderId}`)
    // 处理可能的嵌套data结构
    return response.data.data || response.data
  },

  /**
   * 更新订单状态
   */
  async updateOrderStatus(orderId: number, status: OrderStatus): Promise<void> {
    await request.put(`/orders/${orderId}/status`, { status })
  },

  /**
   * 取消订单
   */
  async cancelOrder(orderId: number, reason?: string): Promise<void> {
    await request.post(`/orders/${orderId}/cancel`, { reason })
  },

  /**
   * 重复下单
   */
  async repeatOrder(orderId: number): Promise<Order> {
    const response = await request.post(`/orders/${orderId}/repeat`)
    // 处理可能的嵌套data结构
    return response.data.data || response.data
  },

  /**
   * 获取订单统计
   */
  async getOrderStats(days: number = 30, userId?: number): Promise<OrderStats> {
    const params: any = { days }
    if (userId) {
      params.user_id = userId
    }
    const response = await request.get('/orders/stats', params)
    // 处理可能的嵌套data结构
    return response.data.data || response.data
  },

  /**
   * 获取用户订单汇总
   */
  async getUserOrderSummary(): Promise<UserOrderSummary> {
    const response = await request.get('/orders/summary')
    // 处理可能的嵌套data结构
    return response.data.data || response.data
  },

  /**
   * 获取今日订单（管理员）
   */
  async getTodayOrders(): Promise<OrderListResponse> {
    const response = await request.get('/orders/today')
    // 处理可能的嵌套data结构
    const data = response.data.data || response.data
    return {
      list: data.list || [],
      total: data.total || 0,
      page: data.page || 1,
      size: data.size || 20
    }
  },

  /**
   * 获取待处理订单（管理员）
   */
  async getPendingOrders(): Promise<OrderListResponse> {
    const response = await request.get('/orders/pending')
    // 处理可能的嵌套data结构
    const data = response.data.data || response.data
    return {
      list: data.list || [],
      total: data.total || 0,
      page: data.page || 1,
      size: data.size || 20
    }
  },

  /**
   * 评价订单
   */
  async reviewOrder(orderId: number, review: { rating: number; comment?: string; emoji?: string }): Promise<OrderReview> {
    const response = await request.post(`/orders/${orderId}/review`, review)
    return response.data.data || response.data
  },

  /**
   * 创建订单回复
   */
  async createOrderReply(orderId: number, content: string): Promise<OrderReply> {
    const response = await request.post(`/orders/${orderId}/replies`, { content })
    return response.data.data || response.data
  },

  /**
   * 获取订单回复列表
   */
  async getOrderReplies(orderId: number): Promise<OrderReply[]> {
    const response = await request.get(`/orders/${orderId}/replies`)
    return response.data.data || []
  }
}

// 订单状态文本映射（温馨互动版）
export const OrderStatusText: Record<OrderStatus, string> = {
  pending: '💭 想吃',
  confirmed: '已确认', // 此状态将被废弃
  cooking: '👨‍🍳 在做啦',
  completed: '🔔 做好啦',
  cancelled: '已取消'
}

// 订单状态颜色映射（用于 UI 显示）
export const OrderStatusColor: Record<OrderStatus, string> = {
  pending: '#FFA726',      // 橙色 - 期待
  confirmed: '#42A5F5',    // 蓝色（废弃状态）
  cooking: '#FF8A65',      // 珊瑚橙 - 温暖
  completed: '#66BB6A',    // 绿色 - 完成
  cancelled: '#999999'     // 灰色 - 取消
}

// 订单工具函数
export const OrderUtils = {
  /**
   * 获取订单状态文本
   */
  getStatusText(status: OrderStatus): string {
    return OrderStatusText[status] || '未知状态'
  },

  /**
   * 获取订单状态颜色
   */
  getStatusColor(status: OrderStatus): string {
    return OrderStatusColor[status] || '#999999'
  },

  /**
   * 格式化订单金额
   */
  formatAmount(amount: number): string {
    return `¥${amount.toFixed(2)}`
  },

  /**
   * 格式化订单时间
   */
  formatOrderTime(dateStr: string): string {
    const date = new Date(dateStr)
    const now = new Date()
    const diffTime = now.getTime() - date.getTime()
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))

    if (diffDays === 0) {
      const hours = date.getHours().toString().padStart(2, '0')
      const minutes = date.getMinutes().toString().padStart(2, '0')
      return `今天 ${hours}:${minutes}`
    } else if (diffDays === 1) {
      const hours = date.getHours().toString().padStart(2, '0')
      const minutes = date.getMinutes().toString().padStart(2, '0')
      return `昨天 ${hours}:${minutes}`
    } else if (diffDays < 7) {
      const hours = date.getHours().toString().padStart(2, '0')
      const minutes = date.getMinutes().toString().padStart(2, '0')
      return `${diffDays}天前 ${hours}:${minutes}`
    } else {
      const month = (date.getMonth() + 1).toString().padStart(2, '0')
      const day = date.getDate().toString().padStart(2, '0')
      const hours = date.getHours().toString().padStart(2, '0')
      const minutes = date.getMinutes().toString().padStart(2, '0')
      return `${month}-${day} ${hours}:${minutes}`
    }
  },

  /**
   * 判断订单是否可以取消
   */
  canCancel(order: Order): boolean {
    return order.status === 'pending' || order.status === 'confirmed'
  },

  /**
   * 判断订单是否可以重复下单
   */
  canRepeat(order: Order): boolean {
    return order.status === 'completed' || order.status === 'cancelled'
  },

  /**
   * 计算订单总数量
   */
  getTotalQuantity(order: Order): number {
    if (!order.items || order.items.length === 0) {
      return order.item_count || 0
    }
    return order.items.reduce((total, item) => total + item.quantity, 0)
  }
}
