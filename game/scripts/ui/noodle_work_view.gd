extends Control
## Original pixel workbench: knead, roll/rest, then cut. This depicts raw dough
## production rather than reusing the ramen-boiling illustration.
var progress: float=0.0
var elapsed: float=0.0
var buckwheat: bool=false
var thick: bool=false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size=Vector2(144,96)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed+=delta
		queue_redraw()

func _draw() -> void:
	var scale_px: int=maxi(1,int(minf(size.x/48.0,size.y/32.0)))
	var origin: Vector2=((size-Vector2(48,32)*scale_px)*0.5).floor()
	var block: Callable=func(x: int,y: int,w: int,h: int,color: Color):
		draw_rect(Rect2(origin+Vector2(x,y)*scale_px,Vector2(w,h)*scale_px),color)
	var ink:=Color("51402e")
	var dough:=Color("ad956c") if buckwheat else Color("f4da91")
	block.call(0,0,48,32,ink)
	block.call(1,1,46,30,Color("b47c47"))
	block.call(3,3,42,26,Color("dfb47b"))
	for y in [7,15,24]: block.call(4,y,40,1,Color("c89a66"))
	var beat: int=int(sin(elapsed*8.0)*2)
	if progress<0.33:
		block.call(13-beat,12,22+beat*2,12,ink)
		block.call(14-beat,12,20+beat*2,10,dough)
		block.call(10+beat,7,8,8,Color("d18e64"))
		block.call(30-beat,7,8,8,Color("d18e64"))
	elif progress<0.7:
		block.call(10,8,28,18,dough)
		var roll: int=10+int((sin(elapsed*5.0)+1.0)*5)
		block.call(6,roll,36,4,ink)
		block.call(10,roll,28,3,Color("bd854e"))
		block.call(11,roll,26,1,Color("e6c08a"))
	else:
		for x in range(9,38,5 if thick else 3):
			var bend: int=int(sin(elapsed*3.0+x)*1.4)
			block.call(x,7,3 if thick else 1,18,dough)
			block.call(x+bend,23,3 if thick else 1,3,dough)
		block.call(37,5,4,18,ink)
		block.call(37,5,3,15,Color("d8e1d8"))
	# Flour dust moves during kneading; all drawing remains text-free.
	for index in 5:
		block.call(5+index*8,27-int(fposmod(elapsed+index,2.0)),1,1,Color("fff2d3"))
