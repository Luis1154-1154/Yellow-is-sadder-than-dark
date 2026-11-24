# renpy_example.rpy — drop-in example for the Rin sprite pack.
#
# Copy the sprites into game/images/rin/ and this file into game/, then run.
# Ren'Py's automatic image naming would also work, but declaring them explicitly
# gives you short, readable names at the call site — `show rin happy` rather than
# `show rin exp 02 happy`.

# ---------------------------------------------------------------- expressions
image rin neutral   = "images/rin/exp-00-neutral.png"
image rin smile     = "images/rin/exp-01-smile.png"
image rin happy     = "images/rin/exp-02-happy.png"
image rin blush     = "images/rin/exp-03-blush.png"
image rin surprised = "images/rin/exp-04-surprised.png"
image rin annoyed   = "images/rin/exp-05-annoyed.png"
image rin sad       = "images/rin/exp-06-sad.png"

# --------------------------------------------------------------------- outfits
image rin casual    = "images/rin/fit-01-casual.png"
image rin uniform   = "images/rin/fit-02-uniform.png"
image rin formal    = "images/rin/fit-03-formal.png"

# The sprites are 832x1248 with straight alpha. At Ren'Py's default 1280x720 that
# is taller than the screen, so scale on show rather than resizing the files —
# keeping the originals full-size means they still look right at 1080p.
transform vn_sprite(z=0.62):
    zoom z
    yalign 1.0
    ypos 1.06          # let the feet sit just off the bottom edge

transform vn_left:
    xalign 0.25
transform vn_right:
    xalign 0.75

define rin = Character("Rin", color="#c99bec")

label rin_demo:
    scene black
    show rin neutral at vn_sprite, vn_left
    with dissolve

    rin "This is the neutral pose."

    show rin smile
    rin "Swapping expression is just another {i}show{/i} — same tag, so it replaces."

    show rin blush
    rin "No compositing, no layered images to align."

    show rin uniform
    rin "Outfits work the same way."

    hide rin with dissolve
    return

# ---------------------------------------------------------------------------
# Want every outfit paired with every expression, pre-rendered?
# The full pack uses the naming fit-<outfit>__exp-<expression>.png, which loops
# cleanly:
#
#   init python:
#       for fit in ["00-signature", "01-casual", "02-uniform", "03-formal"]:
#           for exp in ["00-neutral", "01-smile", "02-happy", "03-blush",
#                       "04-surprised", "05-annoyed", "06-sad"]:
#               renpy.image(
#                   ("rin", fit.split("-", 1)[1], exp.split("-", 1)[1]),
#                   "images/rin/fit-%s__exp-%s.png" % (fit, exp),
#               )
#
#   # then:  show rin uniform blush
# ---------------------------------------------------------------------------
