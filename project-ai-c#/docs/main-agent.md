你正在开发 Godot 4.6.2 项目《???》。请先阅读：
1. README.md
2. Docs/01_GAME_DESIGN_BRIEF.md
3. Docs/02_SYSTEM_SPEC.md
4. Data/*.json

## 一、项目主目录
下面是项目的主要目录结构，不可直接删除和添加其主目录结构，只可添加删除和修改其下的子目录文件夹和文件
项目目录规范

res://
<br>├── docs/          # 提示词文档
<br>├── assets/        # 资源
<br>├────── audio/     # 音频 (.ogg, .wav)
<br>├────── datas/     # 数据 (.json, .csv, .tres)
<br>├────── images/    # 图片 (.png, .jpg, .svg)
<br>├────── shaders/   # 着色器 (.gdshader)
<br>├── scenes/        # 场景 (.tscn)
<br>├────── ui/        # 用户界面场景
<br>├────── levels/    # 关卡场景  
<br>├────── entities/  # 游戏实体场景
<br>├── scripts/       # 脚本 (.gd)
<br>├────── components/# 组件系统脚本
<br>├────── managers/  # 管理器脚本
<br>├────── utils/     # 工具类脚本
<br>├── tests/         # 测试场景
<br>├── tools/         # 开发工具

## 二、约束
你的任务不是自由发挥做一个新游戏，而是在现有设计约束内，
把项目逐步实现成可运行原型

强制要求：
- 使用 Godot 4.x 和 GDScript。
- 先保证可运行，再逐步增强表现。
- 每次提交都要说明改了哪些文件、实现了什么、如何验证。
- 发现设计和修改不清楚时，先在 docs/open-questions.md 记录，你只可添加问题，不可删除原有问题