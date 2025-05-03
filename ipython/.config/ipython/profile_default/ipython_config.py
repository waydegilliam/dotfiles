c = get_config()  # type: ignore

c.TerminalIPythonApp.display_banner = False
c.InteractiveShell.autocall = 1
c.InteractiveShell.autoindent = False
c.InteractiveShellApp.extensions = ["autoreload"]
c.InteractiveShellApp.exec_lines = [
    "%autoreload 2",
    """
    try:
        from pyopp import opp
    except:
        pass
    """,
]
c.TerminalInteractiveShell.editing_mode = "vi"
c.AliasManager.user_aliases = [
    ("c", "clear"),
    ("la", "la"),
    ("ll", "ll"),
    ("lla", "lla"),
]
