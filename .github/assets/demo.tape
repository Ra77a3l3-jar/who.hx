# VHS tape for who.hx — https://github.com/charmbracelet/vhs
# Run with: vhs demo.tape
#
# Uses ~/Dev/ziglings as the sandbox project: it's a git repo with real
# commit history on README.md, so the blame hint has something to show.
#
# No keybind is set for :who-toggle in init.scm, so it's run as a command.

Require hx

Output "/home/raffaele/Dev/plugins/demos/who-demo-catpp.gif"

Set Shell "bash"
Set Theme "VibrantInk"
Set FontFamily "JetBrainsMono Nerd Font Mono"
Set FontSize 18
Set Width 1600
Set Height 1000
Set Padding 20
Set TypingSpeed 60ms
Set WindowBar Colorful

Hide
Type "cd ~/Dev/ziglings && hx README.md"
Enter
Sleep 1.5s
Type ":theme catppuccin_mocha_transparent"
Enter
Sleep 1s
Show

Sleep 500ms

# enable the blame hint — it shows up at the end of the current line
Type ":who-toggle"
Enter
Sleep 800ms

# move across the file — the hint updates to each line's real commit
Down@300ms 8
Sleep 500ms
Down@300ms 6
Sleep 500ms
Down@300ms 5
Sleep 800ms

# disable the hint
Type ":who-toggle"
Enter
Sleep 600ms

Hide
Type ":q!"
Enter
Sleep 500ms
