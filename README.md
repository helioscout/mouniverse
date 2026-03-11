This is a simple space game.\
I am making it in my spare time for fun and learning.\
Feel free to use it as template for your own things.\
\
![Screenshot](pics/screen.png)\
\
Space worlds (game maps) with entities for this game you can create and edit with [moeditor](https://git.sr.ht/~modevstudio/moeditor) project. There you will find also description of the game storage (SQLite database) structure.

### Setup
If you want just to play, you don't have to compile the game to run it, all the necessary release files are located in the folder **bin** (check for your os). Just ensure that `assets` folder located in the same directory with executable (copy if necessary).\
\
To build from source:
1. Setup [Odin](https://odin-lang.org/docs/install/) programming language.
2. Clone all necessary repositories into the same folder:
```sh
git clone https://github.com/karl-zylinski/karl2d.git
git clone https://github.com/flysand7/odin-sqlite3.git
git clone https://git.sr.ht/~modevstudio/moecs
git clone https://git.sr.ht/~modevstudio/mouniverse
```
3. Go to game folder and compile:
```sh
cd mouniverse
odin build . -out:mouniverse.exe -o:aggressive
```
4. Run executable (dependent on your operation system).

### I am using next tools:
| Tool                                      | Purpose                                                           |
|-------------------------------------------|-------------------------------------------------------------------|
| [Odin](https://github.com/odin-lang/Odin) | Programming language.                                             |
| [karl2d](https://github.com/karl-zylinski/karl2d) | For graphics and user events.                             |
| [box2d](https://github.com/erincatto/box2d) | For game physics (Odin's vendor lib).                           |
| [moecs](https://sr.ht/~modevstudio/moecs/) | Entity component system.                                         |
| [sqlite3](https://github.com/flysand7/odin-sqlite3) | SQLite3 bindings for reading/writing to database.       |
| [kenney](http://kenney.nl)                | Awesome free assets.                                              |

### Implemented features

- Moving forward, backward, left, right, angular.
- Extreme (fast) breaking (to full stop).
- Increasing/decreasing max speed.
- Choose weapon type (one/two bullets for now).
- Shots interval (100 ms).
- Impulses (for moving) calculates depending on ship mass.
- Bullet/asteroid contact (collision) animation.

### Control keys
| Key      | Description                   |
|----------|-------------------------------|
| 1        | Change weapon to one bullet.  |
| 2        | Change weapon to two bullets. |
| A        | Move left.                    |
| D        | Move right.                   |
| Up       | Move forward.                 |
| Down     | Move backward.                |
| Left     | Turn left.                    |
| Right    | Turn right.                   |
| Minus    | Minimize speed.               |
| Plus(=)  | Maximize speed.               |
| Q        | Decrease speed (slowly).      |
| E        | Increase speed (slowly).      |
| Space    | Brake (extreme).              |
| W        | Shoot.                        |
| Ctrl+I   | Zoom in.                      |
| Ctrl+O   | Zoom out.                     |
| Ctrl+F   | Full-screen on/off.           |
| Esc      | Show menu (game pause) or back to game (currently unavailable, I will add UI later). |

### Related projects
| Project                                             | Description                                             |
|-----------------------------------------------------|---------------------------------------------------------|
| [moeditor](https://git.sr.ht/~modevstudio/moeditor) | Worlds editor for space game.                           |
| [moecs](https://git.sr.ht/~modevstudio/moecs)       | Entity component system.                                |

[![Hits](https://hits.sh/sr.ht/~modevstudio/mouniverse.svg)](https://hits.sh/sr.ht/~modevstudio/mouniverse/)
