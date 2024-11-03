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
line_height : f32 = font_size * 1.4


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

    start :u32= 0
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
}

populate_editor :: proc(using editor: ^Editor, insert: []u8) {
    text = make([dynamic]u8, 0, len(insert)*2)
    append(&text, ..insert)
    for i in 0..<len(text) {
        if text[i] == '\n' {
            append(&line_breaks, u32(i))
        }
    }
    if text[len(text)-1] != '\n' {
        append(&text, '\n')
    }
}

main :: proc() {
    raylib.InitWindow(1200, 900, "Teditor")
    raylib.SetTargetFPS(300)
    
    font := raylib.LoadFont("./UbuntuMono-Regular.ttf")

    file_name := "first.odin"
    
    text, err := os.read_entire_file_from_filename_or_err(file_name)
    if err != os.ERROR_NONE {
        fmt.println(err)
    }

    editor := Editor{}
    populate_editor(&editor, text)

    
    for !raylib.WindowShouldClose() {
        raylib.BeginDrawing()
        raylib.ClearBackground(bg_color)

        left_width := draw_line_numbers(&editor, f32(height), font_size, font)
        draw_editor(&editor, f32(width), f32(height), f32(left_width), font_size, font)
        
        raylib.EndDrawing()
        free_all(context.temp_allocator)
    }
}

