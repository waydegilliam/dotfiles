import builtins
import pprint


def pp(obj):
    pprint.pprint(obj, indent=2, width=120)


builtins.pp = pp
