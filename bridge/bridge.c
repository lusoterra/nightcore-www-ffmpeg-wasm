/* nightcore-www-ffmpeg-wasm - re-runnable ffmpeg/ffprobe bridge.
 * Copyright (C) 2026 Lev <https://lusosterone.net>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Re-runnable ffmpeg/ffprobe entry points for the wasm core.
 *
 * fftools are single-shot CLIs (main() + exit()). The @ffmpeg/ffmpeg
 * loader instead calls exec()/ffprobe() many times per instance, so:
 *  - the real mains are renamed at compile time (-Dmain=..._tool_main),
 *  - exit() is intercepted with --wrap=exit + longjmp (normal return
 *    also works), and the code lands in Module["ret"] for the loader.
 * Single-threaded: no thread state to reset between runs.
 */
#include <setjmp.h>
#include <emscripten/emscripten.h>

extern int ffmpeg_tool_main(int argc, char **argv);
extern int ffprobe_tool_main(int argc, char **argv);

static jmp_buf exit_jmp;
static int exit_code;

/* noinline: EM_ASM must not be inlined into the setjmp callers below
 * (backend rejects EM_ASM alongside setjmp/longjmp in one function). */
static void __attribute__((noinline)) set_ret(int code) {
    EM_ASM({ Module["ret"] = $0; }, code);
}

int ffmpeg(int argc, char **argv) {
    exit_code = 0;
    if (setjmp(exit_jmp) == 0) {
        exit_code = ffmpeg_tool_main(argc, argv);
    }
    set_ret(exit_code);
    return exit_code;
}

int ffprobe(int argc, char **argv) {
    exit_code = 0;
    if (setjmp(exit_jmp) == 0) {
        exit_code = ffprobe_tool_main(argc, argv);
    }
    set_ret(exit_code);
    return exit_code;
}

/* Linked via -Wl,--wrap=exit: fftools' exit_program() lands here
 * instead of terminating the runtime. */
void __wrap_exit(int status) {
    exit_code = status;
    longjmp(exit_jmp, 1);
}
