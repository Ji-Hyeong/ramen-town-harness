extends RefCounted
## Original code-native pantry icons. Cache tiny alpha sprites; no existing
## finished soup/topping artwork is relabeled as a raw bone or vegetable.
static var cache: Dictionary={}
const INK=Color("51402e")
const LIGHT=Color("fff2d3")

static func ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	for y in 32:
		for x in 32:
			if Vector2((x-center.x)/radius.x,(y-center.y)/radius.y).length_squared()<=1.0:
				img.set_pixel(x,y,color)

static func rect(img: Image, area: Rect2i, color: Color) -> void:
	img.fill_rect(area,color)

static func texture(id: String) -> Texture2D:
	if cache.has(id): return cache[id]
	var img:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	match id:
		"pork_bone","chicken_bone":
			var pink:=Color("c58373") if id=="pork_bone" else Color("c99f68")
			rect(img,Rect2i(10,8,12,17),INK)
			rect(img,Rect2i(12,8,8,18),LIGHT)
			for point in [Vector2(10,8),Vector2(22,8),Vector2(10,25),Vector2(22,25)]:
				ellipse(img,point,Vector2(6,5),INK)
				ellipse(img,point-Vector2(1,1),Vector2(4,3),LIGHT)
			ellipse(img,Vector2(16,16),Vector2(7,5),pink)
			ellipse(img,Vector2(15,15),Vector2(4,3),Color("edbb9d"))
		"kelp":
			for x in [7,15,22]:
				rect(img,Rect2i(x,4,6,24),INK)
				rect(img,Rect2i(x+1,5,3,20),Color("315c3e"))
				rect(img,Rect2i(x+2,7,1,17),Color("718153"))
		"onion":
			ellipse(img,Vector2(16,18),Vector2(12,11),INK)
			ellipse(img,Vector2(16,17),Vector2(10,9),Color("d49b57"))
			ellipse(img,Vector2(15,17),Vector2(7,8),LIGHT)
			ellipse(img,Vector2(15,17),Vector2(5,7),Color("e8c589"))
			rect(img,Rect2i(15,3,3,8),Color("658441"))
		"ginger":
			for point in [Vector2(9,22),Vector2(15,17),Vector2(22,12),Vector2(21,23),Vector2(9,12)]:
				ellipse(img,point,Vector2(6,5),INK)
				ellipse(img,point-Vector2(1,1),Vector2(5,3),Color("cda35d"))
				ellipse(img,point-Vector2(2,2),Vector2(2,1),LIGHT)
		"garlic":
			for point in [Vector2(10,21),Vector2(22,21),Vector2(16,17)]:
				ellipse(img,point,Vector2(6,9),INK)
				ellipse(img,point-Vector2(1,1),Vector2(4,7),LIGHT)
			rect(img,Rect2i(14,3,4,8),Color("ad956d"))
		"clam":
			ellipse(img,Vector2(16,19),Vector2(14,10),INK)
			ellipse(img,Vector2(16,18),Vector2(12,8),Color("bba18b"))
			for x in [7,12,17,22]: rect(img,Rect2i(x,14,2,10),Color("7e6c65"))
			ellipse(img,Vector2(16,25),Vector2(8,2),LIGHT)
		"shiitake":
			rect(img,Rect2i(13,17,7,12),INK)
			rect(img,Rect2i(14,17,4,10),Color("d6b983"))
			ellipse(img,Vector2(16,14),Vector2(14,10),INK)
			ellipse(img,Vector2(16,13),Vector2(12,8),Color("9c673d"))
			for point in [Vector2(11,10),Vector2(19,8),Vector2(23,15),Vector2(12,17)]:
				ellipse(img,point,Vector2(2,1),Color("ebc990"))
		"sardine":
			ellipse(img,Vector2(15,17),Vector2(13,6),INK)
			ellipse(img,Vector2(15,16),Vector2(11,4),Color("b3bcac"))
			rect(img,Rect2i(25,12,5,10),Color("657e7c"))
			for x in [9,14,19]: rect(img,Rect2i(x,13,2,6),Color("99633d"))
			rect(img,Rect2i(5,15,2,2),INK)
		_:
			push_error("Unknown pantry icon: "+id)
	var result:=ImageTexture.create_from_image(img)
	cache[id]=result
	return result
