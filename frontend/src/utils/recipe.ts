// 菜谱数据处理工具函数
import type { Recipe } from '@/api/recipe'

// Base64解码函数
function base64Decode(str: string): string {
  try {
    // 在浏览器环境中使用atob
    if (typeof window !== 'undefined' && window.atob) {
      return window.atob(str)
    }
    // 在其他环境中的处理
    return str
  } catch (error) {
    console.error('Base64解码失败:', error)
    return str
  }
}

// 解析ingredients字段
export function parseIngredients(ingredients: string): string[] {
  try {
    // 如果是base64编码的JSON
    if (ingredients && !ingredients.startsWith('[')) {
      const decoded = base64Decode(ingredients)
      return JSON.parse(decoded)
    }
    // 如果是普通JSON字符串
    if (ingredients && ingredients.startsWith('[')) {
      return JSON.parse(ingredients)
    }
    return []
  } catch (error) {
    console.error('解析ingredients失败:', error)
    return []
  }
}

// 解析steps字段
export function parseSteps(steps: string): string[] {
  try {
    // 如果是base64编码的JSON
    if (steps && !steps.startsWith('[')) {
      const decoded = base64Decode(steps)
      return JSON.parse(decoded)
    }
    // 如果是普通JSON字符串
    if (steps && steps.startsWith('[')) {
      return JSON.parse(steps)
    }
    return []
  } catch (error) {
    console.error('解析steps失败:', error)
    return []
  }
}

// 解析tags字段
export function parseTags(tags: string): string[] {
  try {
    // 如果是逗号分隔的字符串
    if (tags && typeof tags === 'string') {
      return tags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0)
    }
    return []
  } catch (error) {
    console.error('解析tags失败:', error)
    return []
  }
}

// 格式化难度等级
export function formatDifficulty(difficulty: string): number {
  const difficultyMap: Record<string, number> = {
    'easy': 1,
    'medium': 2,
    'hard': 3
  }
  return difficultyMap[difficulty] || 1
}

// 格式化难度文本
export function formatDifficultyText(difficulty: string): string {
  const difficultyMap: Record<string, string> = {
    'easy': '简单',
    'medium': '中等',
    'hard': '困难'
  }
  return difficultyMap[difficulty] || '简单'
}

// 处理菜谱数据，转换为前端需要的格式
export function processRecipe(recipe: Recipe): Recipe & {
  ingredientsList: string[]
  stepsList: string[]
  tagsList: string[]
  difficultyLevel: number
  difficultyText: string
} {
  return {
    ...recipe,
    ingredientsList: parseIngredients(recipe.ingredients),
    stepsList: parseSteps(recipe.steps),
    tagsList: parseTags(recipe.tags),
    difficultyLevel: formatDifficulty(recipe.difficulty),
    difficultyText: formatDifficultyText(recipe.difficulty)
  }
}

// 批量处理菜谱列表
export function processRecipeList(recipes: Recipe[]): Array<Recipe & {
  ingredientsList: string[]
  stepsList: string[]
  tagsList: string[]
  difficultyLevel: number
  difficultyText: string
}> {
  return recipes.map(processRecipe)
}

// 获取菜谱的显示标签
export function getRecipeDisplayTags(recipe: Recipe): string[] {
  const tags = parseTags(recipe.tags)
  const difficultyText = formatDifficultyText(recipe.difficulty)
  
  // 合并标签和难度
  return [...tags, difficultyText]
}

// 检查菜谱是否为收藏
export function isRecipeFavorite(recipe: Recipe): boolean {
  return recipe.is_favorite || false
}

// 格式化烹饪时间
export function formatCookingTime(minutes: number): string {
  if (minutes < 60) {
    return `${minutes}分钟`
  } else {
    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    if (remainingMinutes === 0) {
      return `${hours}小时`
    } else {
      return `${hours}小时${remainingMinutes}分钟`
    }
  }
}

// 格式化人份数
export function formatServings(servings: number): string {
  return `${servings}人份`
}

// 获取菜谱的完整显示信息
export function getRecipeDisplayInfo(recipe: Recipe) {
  const processed = processRecipe(recipe)
  
  return {
    ...processed,
    cookingTimeText: formatCookingTime(recipe.cooking_time),
    servingsText: formatServings(recipe.servings),
    displayTags: getRecipeDisplayTags(recipe),
    isFavorite: isRecipeFavorite(recipe)
  }
}

// 导出默认工具对象
export default {
  parseIngredients,
  parseSteps,
  parseTags,
  formatDifficulty,
  formatDifficultyText,
  processRecipe,
  processRecipeList,
  getRecipeDisplayTags,
  isRecipeFavorite,
  formatCookingTime,
  formatServings,
  getRecipeDisplayInfo
}
