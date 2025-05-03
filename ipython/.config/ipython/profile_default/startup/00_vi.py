from IPython import get_ipython
from prompt_toolkit.enums import DEFAULT_BUFFER
from prompt_toolkit.filters import HasFocus, ViInsertMode
from prompt_toolkit.key_binding.vi_state import InputMode

ip = get_ipython()


def switch_to_navigation_mode(event):
    vi_state = event.cli.vi_state
    vi_state.input_mode = InputMode.NAVIGATION


if getattr(ip, "pt_app", None):
    registry = ip.pt_app.key_bindings
    registry.add_binding("j", "k", filter=(HasFocus(DEFAULT_BUFFER) & ViInsertMode()))(
        switch_to_navigation_mode
    )
