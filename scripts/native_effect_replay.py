"""Local-only native PS1 replays; private fixtures and reports never leave the host."""
from pathlib import Path
import ctypes as C,importlib,json,sys
ROOT=Path(__file__).resolve().parents[1]
PC=ROOT.parent/'swanstation_v82_probe'
sys.dont_write_bytecode=True

class Output:
    def __init__(self,out):self.out=out
    def __truediv__(self,name):
        if name in ('player_diagnostic_ram.bin','fix2_integration/dropfix_native_result_ram.bin'):return PC/name
        return self.out/name

def replay(dll,output,encoded=None):
    sys.path.insert(0,str(PC))
    import player_compat
    from player_trap_compat import PATCHES
    from player_effect_compat import NAME_AT,NAME_FIXED,ATTACK_AT,ATTACK_FIXED
    lib=C.CDLL(str(dll))
    lib.legend_apply.argtypes=[C.c_void_p,C.c_size_t,C.c_char_p];lib.legend_apply.restype=C.c_int
    if encoded:
        lib.legend_configure.argtypes=[C.c_void_p,C.c_size_t,C.c_bool]
        blob=encoded.read_bytes();lib.legend_configure(C.create_string_buffer(blob),len(blob),True)
    class MobileCompatibility:
        def __init__(self,digest):self.digest=digest;self.conflict=False;self.applied=set()
        def apply(self,ptr,size):
            self.conflict=bool(lib.legend_apply(ptr,size,self.digest.encode()))
            if self.digest not in player_compat.KNOWN or not ptr or size<0x200000:return
            if all(C.string_at(ptr+at,len(new))==new for at,old,new in PATCHES):self.applied.add('trap_load_delays')
            for at,code,name in [(NAME_AT,NAME_FIXED,'card_name_scene_guard'),(ATTACK_AT,ATTACK_FIXED,'multiattack_load_delay')]:
                if C.string_at(ptr+at,len(code))==code:self.applied.add(name)
    player_compat.ModCompatibility=MobileCompatibility
    output.mkdir(exist_ok=True,parents=True)
    for name in ('test_player_card_effects','test_player_traps','test_summon_destruction'):
        test=importlib.import_module(name);test.HERE=Output(output) if name=='test_player_card_effects' else output
        test.main()
    report={'passed':True,'patcher':str(dll),'actual_java_encoding':bool(encoded),'actual_native_functions':True,
            'reports':['player_card_effects_report.json','player_traps_report.json','player_summon_destruction_report.json'],
            'device_gameplay_tested':False}
    (output/'mobile_effects_report.json').write_text(json.dumps(report,indent=2))
