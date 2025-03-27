# VTB - 智能语音助手

VTB是一款基于iOS平台的智能语音助手应用，能够将用户的语音转换为文字，并通过AI进行文本优化和主题分析。

## 核心功能

### 1. 语音录制
- 通过底部录音按钮进行语音录制
- 支持录音状态实时显示
- 录音完成后自动进行后续处理

### 2. 语音转文字
- 使用Silicon Flow API进行语音识别
- 实时显示转换进度
- 支持中文语音识别

### 3. 文本优化
- 使用Silicon Flow Chat API进行文本润色
- 自动纠正错别字和语法错误
- 优化文本表达流畅度
- 生成相关主题标签

## 界面设计

### 1. 首页（Home）
- 大型录音按钮位于底部
- 录音状态显示
- 转换后的文本展示区域
- 优化后的文本展示区域
- 相关标签展示

### 2. 历史记录（History）
- 按时间倒序展示历史记录
- 每条记录包含：
  - 录音文件
  - 原始转录文本
  - 优化后的文本
  - 相关标签
- 支持记录删除功能

### 3. 个人中心（Profile）
- 预留功能扩展空间
- 基础设置选项

## 技术实现

### 架构设计
- 使用SwiftUI构建用户界面
- MVVM架构模式
- CoreData进行本地数据存储
- AVFoundation处理音频录制
- 网络层封装API调用

### 数据模型
```swift
struct Recording {
    let id: UUID
    let audioURL: URL
    let transcription: String
    let enhancedText: String
    let tags: [String]
    let createdAt: Date
}
```

### API集成
- 语音转文字API: Silicon Flow Audio Transcriptions
- 文本优化API: Silicon Flow Chat Completions
- API密钥安全存储

## 开发计划

### 第一阶段：基础框架搭建
1. 创建项目基础结构
2. 实现TabView导航
3. 设计数据模型
4. 搭建网络层

### 第二阶段：核心功能实现
1. 实现录音功能
2. 集成语音转文字API
3. 集成文本优化API
4. 实现本地数据存储

### 第三阶段：UI完善
1. 实现首页界面
2. 实现历史记录界面
3. 实现个人中心界面
4. 优化用户体验

### 第四阶段：测试与优化
1. 单元测试
2. UI测试
3. 性能优化
4. Bug修复

## 注意事项
- API密钥安全存储
- 录音文件本地存储管理
- 网络请求错误处理
- 用户隐私保护
- 内存管理优化

## 环境要求
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+ 