"""Finder layout for the signed, already-built application. Uses dmgbuild 1.6.7."""
import os

application = os.path.abspath(defines["app"])
files = [application]
symlinks = {"Applications": "/Applications"}
format = "UDZO"
filesystem = "HFS+"
size = "32m"
icon = os.path.join(application, "Contents", "Resources", "AppIcon.icns")
background = os.path.abspath(defines["background"])
window_rect = ((180, 180), (660, 420))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 14
label_pos = "bottom"
icon_locations = {"Monthly Native.app": (170, 208), "Applications": (490, 208)}
# Do not set FinderInfo on the signed bundle (including hide_extensions):
# codesign --strict rejects that additional metadata.
