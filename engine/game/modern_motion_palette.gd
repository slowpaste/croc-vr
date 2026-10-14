extends RefCounted
# Semantic roles for the complete player palette. The source strategy chooses
# contextual actions; modern locomotion supplies intent, never a fixed clip list.
const FAMILIES := {
	"walk":["CROCSTWK.ANI","CROCWALK.ANI","CROCINWA.ANI"],
	"run":["CROCRUN.ANI","CROCWW2R.ANI","CROCWR2W.ANI","CROCSKID.ANI"],
	"backward":["CROCBKW1.ANI","CROCBKW2.ANI","CROCBKW3.ANI"],
	"sidestep":["CROCSLT2.ANI","CROCSLT3.ANI","CROCSRT2.ANI","CROCSRT3.ANI"],
	"turn":["CROCLEFT.ANI","CROCRGHT.ANI","CROCTLT1.ANI","CROCTLT2.ANI","CROCTRT1.ANI","CROCTRT2.ANI"],
	"reversal":["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"],
	"jump":["CROCJMP2.ANI","CROCJMP3.ANI","CROCJMP4.ANI","CROCJMP5.ANI"],
	"lava escape":["CROCLJP2.ANI","CROCLJP3.ANI","CROCLJP4.ANI","CROCLJP5.ANI"],
	"stomp":["CROCSMP1.ANI","CROCSMP2.ANI","CROCSMP3.ANI","CROCSMP4.ANI"],
	"attack":["CROCATK2.ANI","CROCATK3.ANI","CROCATK4.ANI","CROCATK5.ANI","SWIMATTK.ANI","SWIMATT2.ANI"],
	"ledge":["CROCEDCL.ANI","CROCEDLD.ANI","CROCEDOF.ANI","CROCEDUP.ANI","CROCEDWT.ANI"],
	"push":["CROCPUSH.ANI","CROCPUSP.ANI","CROCPUST.ANI"],
	"slide":["CROCSFSP.ANI","CROCSLLP.ANI","CROCSLSP.ANI","SWIMSLSP.ANI","SWIMSLST.ANI"],
	"surf":["CROCSURF.ANI"],
	"reaction":["CROCGHIT.ANI","CROCDIE1.ANI","SWIMCRHT.ANI","SWIMDRWN.ANI"],
	"celebration":["CROCVICT.ANI"],
	"swim":["SWIM.ANI","SWIMSLOW.ANI","SWIMWAIT.ANI"],
	"swim turn":["SWIM180.ANI","SWIMTRNL.ANI","SWIMTRNR.ANI"],
	"swim sidestep":["SWIMSIDL.ANI","SWIMSIDR.ANI"]
}
const LOOPS := ["CROCWALK.ANI","CROCSTWK.ANI","CROCRUN.ANI","CROCBKW2.ANI","CROCSLT2.ANI","CROCSRT2.ANI","CROCPUSH.ANI"]
static func family(name: String) -> String:
	if name.begins_with("CROCWA") and name.substr(6,1).is_valid_int(): return "idle"
	if name.begins_with("CROC_C"): return "climb"
	if name.begins_with("CROC_H"): return "hang"
	for role in FAMILIES:
		if FAMILIES[role].has(name): return role
	return ""
static func motion_driven(name: String) -> bool:
	return family(name) in ["walk","run","backward","sidestep","turn","reversal"]
static func reversal(name: String) -> bool:
	return family(name) == "reversal"
static func blendable(name: String) -> bool:
	return family(name) in ["idle","walk","run","backward","sidestep","turn"]
