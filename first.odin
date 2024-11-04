package main

import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:os/"
import "vendor:raylib"

bg_color :: raylib.Color{27, 23, 42, 255}
line_nr_bg_color :: raylib.Color{20, 21, 15, 255}
line_nr_color :: raylib.Color{99, 100, 220, 255}
cursor_color :: raylib.Color{99, 200, 220, 255}
text_color :: raylib.Color{218, 218, 208, 255}
text2_color :: raylib.Color{255, 188, 118, 255}

// in pixels
width : i32 = 1200
height : i32 = 900
font_size : f32 = 32.0
font_spacing : f32 = 0.0 * font_size
line_height : f32 = font_size * 1.1

draw_cursor :: proc(using editor: ^Editor, pos_x: f32, font_size: f32, font: raylib.Font) {
    line_nr, line_col, start := get_cursor(line_breaks[:], cursor)
    line_so_far := fmt.ctprintf("%s", text[start:start+line_col])
    size := raylib.MeasureTextEx(font, line_so_far, font_size, font_spacing)
    cursor_pos := raylib.Vector2{pos_x + size.x, cast(f32)(line_nr)*line_height}
    cursor_size := raylib.Vector2{font_size * 0.5, line_height}
    raylib.DrawRectangleV(cursor_pos, cursor_size, cursor_color)
}

draw_line_numbers :: proc(editor: ^Editor, height: f32, font_size: f32, font: raylib.Font) -> f32 {
    max_width : f32 = 0
    for _, index in editor.line_breaks {
        to_print := fmt.ctprintf("%d", index)
        v := raylib.MeasureTextEx(font, to_print, font_size, font_spacing)
        if v.x > max_width {
            max_width = v.x
        }
    }

    raylib.DrawRectangle(0, 0, cast(i32)max_width, cast(i32)height, line_nr_bg_color)
    for _, index in editor.line_breaks {
        to_print := fmt.ctprintf("%d", index)

        size := raylib.MeasureTextEx(font, to_print, font_size, font_spacing)
        line_pos := raylib.Vector2{0, f32(index + 1) * line_height - size.y}
        //raylib.DrawRectangleV(line_pos, size, raylib.RED)
        raylib.DrawTextEx(font, to_print, line_pos, font_size, 0, line_nr_color)
    }

    return max_width
}

draw_editor :: proc(using editor: ^Editor, width: f32, height: f32, pos_x: f32, font_size: f32, font: raylib.Font) {

    draw_cursor(editor, pos_x, font_size, font)

    start: u32 = 0
    for line_break, index in line_breaks {
        line := fmt.ctprintf("%s", text[start:line_break])
        start = line_break

        size := raylib.MeasureTextEx(font, line, font_size, font_spacing)
        line_pos := raylib.Vector2{pos_x, f32(index + 1) * line_height - size.y}

        //raylib.DrawRectangleV(line_pos, size, raylib.BEIGE)
        raylib.DrawTextEx(
            font,
            line,
            line_pos,
            font_size,
            font_spacing,
            text_color,
        )
    }
}


Editor :: struct {
    text: [dynamic]u8,
    line_breaks: [dynamic]u32,
    cursor: int,
    last_col: int, // set when cursor column is smaller than previous
}

populate_editor :: proc(using editor: ^Editor, insert: []u8) {
    text = make([dynamic]u8, 0, len(insert)*2 + 1)

    append(&text, ..insert)

    // the assumtion is: we have at least one newline
    // we insert a line_break at the end if there is none
    if len(text) == 0 || text[len(text)-1] != '\n' {
        append(&text, '\n')
    }

    recalculate_line_breaks(editor)
}

simulate_editor :: proc(using editor: ^Editor) {
    if raylib.IsKeyPressed(raylib.KeyboardKey.RIGHT) || raylib.IsKeyPressedRepeat(raylib.KeyboardKey.RIGHT) {
        move_cursor_right(editor)
    }

    if raylib.IsKeyPressed(raylib.KeyboardKey.LEFT) ||  raylib.IsKeyPressedRepeat(raylib.KeyboardKey.LEFT) {
        move_cursor_left(editor)
    }

    if raylib.IsKeyPressed(raylib.KeyboardKey.DOWN) || raylib.IsKeyPressedRepeat(raylib.KeyboardKey.DOWN) {
        move_cursor_down(editor)
    }

    if raylib.IsKeyPressed(raylib.KeyboardKey.UP) ||  raylib.IsKeyPressedRepeat(raylib.KeyboardKey.UP) {
        move_cursor_up(editor)
    }

    cursor = clamp(cursor, 0, len(text))

    char := raylib.GetCharPressed()
    if (char != 0) {
        insert_char_at_cursor(editor, char)
    }

    if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
        insert_char_at_cursor(editor, '\n')
    }

    if raylib.IsKeyPressed(raylib.KeyboardKey.BACKSPACE) {
        delete_char_at_cursor(editor)
    }

}

delete_char_at_cursor :: proc(using e: ^Editor) {
    if cursor <= 0 do return
    cursor -= 1
    ordered_remove(&text, cursor)
    recalculate_line_breaks(e)
}

insert_char_at_cursor :: proc(using e: ^Editor, char: rune) {
    // TODO: support unicode
    small := cast(u8)char
    inject_at(&text, cursor, small)
    cursor += 1
    recalculate_line_breaks(e)
}

recalculate_line_breaks :: proc(using e: ^Editor) {
    clear(&line_breaks)
    for i in 0..<len(text) {
        if text[i] == '\n' {
            append(&line_breaks, u32(i))
        }
    }
}

move_cursor_left :: proc(using editor: ^Editor) {
    cursor -= 1
    _, last_col, _ = get_cursor(line_breaks[:], cursor)
}

move_cursor_right :: proc(using editor: ^Editor) {
    cursor += 1
    _, last_col, _ = get_cursor(line_breaks[:], cursor)
}

move_cursor_down :: proc(using e: ^Editor) {
    n, c, s := get_cursor(line_breaks[:], cursor)
    c = max(last_col, c)

    // assuming it is the last character of the file (gets inserted anyway for now!)
    last := int(line_breaks[len(line_breaks)-1])

    if n+1 >= len(line_breaks) {
        // next line is EOF just return end i.e. last line break
        // not sure if this can happen.
        cursor = last
        return
    }

    next_start := int(line_breaks[n]) + 1
    next_lb := int(line_breaks[n+1])

    if (next_lb - next_start < c) {
        last_col = c
        c = next_lb - next_start
    }

    cursor = clamp(next_start + c, 0, last)
}

move_cursor_up :: proc(using e: ^Editor) {
    n, c, s := get_cursor(line_breaks[:], cursor)
    c = max(last_col, c)

    // first line so we go to beginning of file
    if n == 0 {
        cursor = 0
        return
    }

    prev_start := n > 1 ? int(line_breaks[n-2]) + 1 : 0
    prev_lb := s - 1

    if (prev_lb - prev_start <= c) {
        last_col = c
        c = prev_lb - prev_start
    }

    // assuming last line break is the last character of the file
    last := int(line_breaks[len(line_breaks)-1])
    cursor = clamp(prev_start+c, 0, last)
}

get_cursor :: proc(line_breaks: []u32, cursor: int) -> (int, int, int) {
    line_nr: int = 0
    line_col: int = cursor
    line_start: int = 0

    for lb, i in line_breaks {
        if cursor <= int(lb) {
            line_start = i > 0 ? int(line_breaks[i-1]) + 1 : 0
            line_nr = i
            line_col = cursor - line_start
            break
        }
    }

    return line_nr, line_col, line_start
}

parse_args :: proc() -> (string, []u8, bool) {

    shift :: proc(args: ^[]string) -> string {
        ret := args[0]
        args^ = args[1:]
        return ret
    }

    // assume first arguent is always the program
    args := os.args
    program_name := shift(&args)

    if len(args) == 0 {
        fmt.printf ("Usage: %s <filename>\n", program_name)
        fmt.println("Error: no filename provided")
        return "", {}, false
    }

    if len(args) >= 2 {
        fmt.printf ("Usage: %s <filename>\n", program_name)
        fmt.println("Error: too many arguments provided")
        return "", {}, false
    }

    file_name := shift(&args)
    text : []u8
    if os.is_file(file_name) {
        success: bool
        text, success = os.read_entire_file_from_filename(file_name)
        if !success {
            fmt.printfln("Error: the file named `` could not be opend for whatever reason.", file_name)
            return "", {}, false
        }
    }

    return file_name, text, true
}


main :: proc() {

    file_name, text, success := parse_args()
    if !success {
        os.exit(1)
    }

    editor := Editor{}
    populate_editor(&editor, text)

    raylib.InitWindow(1200, 900, "Teditor")
    raylib.SetTargetFPS(300)

    font := raylib.LoadFont("./UbuntuMono-Regular.ttf")


    for !raylib.WindowShouldClose() {

        simulate_editor(&editor)

        raylib.BeginDrawing()
        raylib.ClearBackground(bg_color)

        left_width := draw_line_numbers(&editor, f32(height), font_size, font)
        draw_editor(&editor, f32(width), f32(height), f32(left_width), font_size, font)

        raylib.EndDrawing()
        free_all(context.temp_allocator)
    }
}

