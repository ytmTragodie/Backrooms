class_name StartScreen
extends Control
## 应用导航外壳，仅持有 MENU/INTRO/GAME 界面阶段。RunState 仍由原 TurnManager 创建。
enum Page { MENU, INTRO, GAME, CLOSING }
signal section_requested(section: StringName)
const RESERVED: Dictionary = {&"continue":"存档与读取尚未开放",&"settings":"设置页面尚未开放；已预留主音量、音乐与音效入口",&"codex":"图鉴尚未开放；本阶段保持原有地图与卡牌规则"}
const GAME_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
@export var opening: OpeningStoryData
var page: Page = Page.MENU
var game_view: MainGameView
var story_view: OpeningStoryView
var _menu: Control
var start_button: Button
var _menu_notice: Label

func _ready() -> void:
	theme = GameUITheme.build()
	get_tree().auto_accept_quit = false
	_show_menu()

func _show_menu() -> void:
	page = Page.MENU
	(get_node("/root/GameAudio") as AssetAudio).play_context(&"music_menu")
	_menu = Control.new()
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = GameUITheme.texture(_menu,&"menu_background")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025,0.025,0.018,0.78)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = 460
	box.add_theme_constant_override("separation",10)
	center.add_child(box)
	var code: Label = GameUITheme.label(box,"M.E.G. / FIELD ARCHIVE / 000",14,GameUITheme.GOLD)
	GameUITheme.apply_role(code,&"archive")
	var title: Label = GameUITheme.label(box,"后室：切出",60)
	GameUITheme.apply_role(title,&"display")
	var subtitle: Label = GameUITheme.label(box,"BACKROOMS: CUT OUT",20,GameUITheme.GOLD)
	GameUITheme.apply_role(subtitle,&"archive")
	GameUITheme.label(box,"陌生的空间，有限的选择。找到离开的路。",16)
	start_button = _menu_button(box,"开始游戏",begin_run)
	_menu_button(box,"继续游戏",request_section.bind(&"continue"),RESERVED[&"continue"])
	_menu_button(box,"设置",request_section.bind(&"settings"),RESERVED[&"settings"])
	_menu_button(box,"游戏说明 / 图鉴",request_section.bind(&"codex"),RESERVED[&"codex"])
	_menu_button(box,"退出游戏",_quit)
	_menu_notice = GameUITheme.label(box,"未开放入口已禁用，可悬停查看说明。",12,GameUITheme.GOLD)
	start_button.grab_focus()

func _menu_button(parent: Node, text_value: String, action: Callable, placeholder: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.disabled = not placeholder.is_empty()
	button.tooltip_text = placeholder
	parent.add_child(button)
	if action.is_valid(): button.pressed.connect(action)
	return button

func request_section(section: StringName) -> void:
	# 未来设置/存档/图鉴共用的稳定导航接口；当前只反馈占位，不伪造业务。
	if page != Page.MENU or not RESERVED.has(section): return
	_menu_notice.text = RESERVED[section]
	section_requested.emit(section)

func begin_run() -> void:
	if page != Page.MENU: return
	page = Page.INTRO
	start_button.disabled = true
	remove_child(_menu)
	_menu.queue_free()
	story_view = OpeningStoryView.new()
	story_view.story = opening
	story_view.completed.connect(_enter_game)
	add_child(story_view)

func _enter_game() -> void:
	if page != Page.INTRO: return
	page = Page.GAME
	remove_child(story_view)
	story_view.queue_free()
	story_view = null
	# 只在演出结束后实例化一次旧 Main；不先调用 start_run 再让 _ready 重复初始化。
	game_view = GAME_SCENE.instantiate() as MainGameView
	game_view.return_to_menu_requested.connect(_return_to_menu)
	add_child(game_view)

func _return_to_menu() -> void:
	if page != Page.GAME: return
	remove_child(game_view)
	game_view.queue_free()
	game_view = null
	_show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree(): _quit()

func _quit() -> void:
	if page == Page.CLOSING: return
	page = Page.CLOSING
	(get_node("/root/GameAudio") as AssetAudio).stop_all()
	# 让设备线程释放本轮播放缓冲后再退出；不影响任何玩法时间或 RNG。
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
