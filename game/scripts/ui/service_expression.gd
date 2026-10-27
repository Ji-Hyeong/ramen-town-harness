extends RefCounted
## Read-only transition observer. It never advances a service or awards money.
## Seeding a newly attached session suppresses old events; repeated snapshots
## cannot replay reactions. Only currently visible patrons remain in memory.
const Session=preload("res://scripts/domain/service_session.gd")
const REACTIONS: Array[String]=["heart","note","smile","meh","angry"]
const MAX_EVENTS: int=24
const DURATION: float=0.90
var _seeded: bool=false
var _people: Dictionary={}
var _cooking: bool=false
var _ready: int=0
var _carrying: bool=false
var _events: Array[Dictionary]=[]
var _count: int=0


func reset(snapshot: Dictionary={}) -> void:
	_seeded=false
	_people.clear()
	_events.clear()
	_cooking=false
	_ready=0
	_carrying=false
	_count=0
	if not snapshot.is_empty(): observe(snapshot)


func advance(seconds: float) -> void:
	for event in _events: event["age"]+=maxf(0.0,seconds)
	_events=_events.filter(func(event: Dictionary) -> bool: return float(event["age"])<DURATION)


func observe(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	var people: Dictionary={}
	var cooking: bool=bool(snapshot["chef_cooking"])
	var ready: int=int(snapshot["ready"])
	var carrying: bool=int(snapshot["server_state"])==Session.S_CARRY
	if _seeded:
		if cooking and not _cooking: _emit("cook")
		if ready>_ready: _emit("ready")
		if carrying and not _carrying: _emit("carry",-1,int(snapshot["server_seat"]))
	for person in snapshot["patrons"]:
		var id: int=int(person["id"])
		var state: int=int(person["state"])
		var bubble: String=str(person["bubble"])
		var old: Dictionary=_people.get(id,{})
		if _seeded:
			if state==Session.P_EATING and int(old.get("state",-1))!=state:
				_emit("served",id,int(person["seat"]))
			if bubble in REACTIONS and str(old.get("bubble",""))!=bubble:
				_emit("reaction",id,int(person["seat"]),bubble)
		people[id]={"state":state,"bubble":bubble}
	_people=people
	_cooking=cooking
	_ready=ready
	_carrying=carrying
	_seeded=true


func _emit(kind: String, id: int=-1, seat: int=-1, reaction: String="") -> void:
	if _events.size()>=MAX_EVENTS: _events.pop_front()
	_events.append({"kind":kind,"id":id,"seat":seat,"reaction":reaction,"age":0.0})
	_count+=1


func events() -> Array[Dictionary]:
	return _events.duplicate(true)


func age(kind: String, id: int=-1) -> float:
	for event in _events:
		if event["kind"]==kind and int(event["id"])==id: return float(event["age"])
	return -1.0


func transition_count() -> int:
	return _count
