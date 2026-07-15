#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import os
import time

PIDFILE = "/tmp/stream_brb.pid"
MESSAGE = os.environ.get("BRB_MSG", "STREAM ON BREAK")
IMAGE = os.environ.get("BRB_IMG", "")

with open(PIDFILE, "w") as f:
    f.write(str(os.getpid()))

start_time = time.time()

win = Gtk.Window()
win.set_title("stream_brb")
win.fullscreen()
win.set_keep_above(True)
win.stick()

rgba = Gdk.RGBA()
rgba.parse("rgba(13, 13, 27, 1)")
win.override_background_color(Gtk.StateFlags.NORMAL, rgba)

win.connect("destroy", Gtk.main_quit)
win.connect("key-press-event", lambda w, e: Gtk.main_quit())
win.connect("button-press-event", lambda w, e: Gtk.main_quit())

overlay = Gtk.Overlay()
win.add(overlay)

if IMAGE and os.path.isfile(IMAGE):
    bg = Gtk.Image.new_from_file(IMAGE)
    overlay.add_overlay(bg)

vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
vbox.set_valign(Gtk.Align.CENTER)
vbox.set_halign(Gtk.Align.CENTER)
overlay.add_overlay(vbox)

label_brb = Gtk.Label()
label_brb.set_markup(f'<span font="72" weight="bold" color="white">{GLib.markup_escape_text(MESSAGE)}</span>')
vbox.pack_start(label_brb, False, False, 0)

timer_label = Gtk.Label()
timer_label.set_markup('<span font="36" color="#aaaaaa">00:00:00</span>')
vbox.pack_start(timer_label, False, False, 20)

label_sub = Gtk.Label()
label_sub.set_markup('<span font="20" color="#666666">Press ESC or click to resume</span>')
vbox.pack_start(label_sub, False, False, 0)

def update_timer():
    elapsed = int(time.time() - start_time)
    h = elapsed // 3600
    m = (elapsed % 3600) // 60
    s = elapsed % 60
    timer_label.set_markup(f'<span font="36" color="#aaaaaa">{h:02d}:{m:02d}:{s:02d}</span>')
    return True

GLib.timeout_add(1000, update_timer)

def on_destroy(*args):
    try:
        os.remove(PIDFILE)
    except OSError:
        pass

win.connect("destroy", on_destroy)

win.show_all()
Gtk.main()
