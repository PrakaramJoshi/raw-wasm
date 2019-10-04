(import "Math" "random" (func $random (result f32)))
(import "Math" "sin" (func $sin (param f32) (result f32)))

;; Color: u32       ; ABGR
;; Cell2: u8*2      ; left/up cell, right/down cell
;; Wall: f32*5      ; (x1,y1) -> (x2, y2), and x-scale

;; [0x0000, 0x0100)   u8[12*12]       maze cells for Kruskal's algo
;; [0x0100, 0x0310)   Cell2[12*11*2]  walls for Kruskal's algo
;; [0x0400, 0x0500)   u8[32*32/4]     2bpp brick texture
;; [0x0500, 0x0600)   u8[32*32/4]     2bpp floor/ceil texture
;; [0x0c00, 0x0c02)   u8[3]           left/right/forward keys
;; [0x0d00, 0x0d1c)   Color[4+3+3]    palettes
;; [0x0e00, 0x0fe0)   f32[120]        Table of 120/(120-y)
;; [0x1000, 0x19c4)   Wall[11*11+4]   walls used in-game
;; [0x3000, 0x4e000)  Color[320*240]  canvas
(memory (export "mem") 6)

(data (i32.const 0x1000)
  ;; top wall
  "\00\00\00\00"  ;; 0.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\40\41"  ;; scale=+24
  ;; right wall
  "\00\00\c0\41"  ;; 24.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\40\41"  ;; scale=24
  ;; bottom wall
  "\00\00\c0\41"  ;; 24.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\40\41"  ;; scale=24
  ;; left wall
  "\00\00\00\00"  ;; 0.0
  "\00\00\c0\41"  ;; 24.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\00\00"  ;; 0.0
  "\00\00\40\41"  ;; scale=24
)

;; brick texture 2bpp
(data (i32.const 0x400)
  "\aa\aa\aa\aa\aa\aa\aa\aa\00\00\00\00\02\00\00\00\ff\ff\ff\7f\f2\ff\ff\ff"
  "\ff\ff\ff\7f\f2\ff\ff\ff\fc\fc\fc\7c\f2\fc\fc\fc\f7\f7\f7\77\f2\f7\f7\f7"
  "\ff\ff\ff\7f\f2\ff\ff\ff\ff\ff\ff\7f\f2\ff\ff\ff\fc\fc\fc\7c\f2\fc\fc\fc"
  "\f7\f7\f7\77\f2\f7\f7\f7\ff\ff\ff\7f\f2\ff\ff\ff\ff\ff\ff\7f\f2\ff\ff\ff"
  "\fc\fc\fc\7c\f2\fc\fc\fc\f7\f7\f7\77\f2\f7\f7\f7\ff\ff\ff\7f\f2\ff\ff\ff"
  "\55\55\55\55\52\55\55\55\aa\aa\aa\aa\aa\aa\aa\aa\02\00\00\00\00\00\00\00"
  "\f2\ff\ff\ff\ff\ff\ff\7f\f2\ff\ff\ff\ff\ff\ff\7f\f2\fc\fc\fc\fc\fc\fc\7c"
  "\f2\f7\f7\f7\f7\f7\f7\77\f2\ff\ff\ff\ff\ff\ff\7f\f2\ff\ff\ff\ff\ff\ff\7f"
  "\f2\fc\fc\fc\fc\fc\fc\7c\f2\f7\f7\f7\f7\f7\f7\77\f2\ff\ff\ff\ff\ff\ff\7f"
  "\f2\ff\ff\ff\ff\ff\ff\7f\f2\fc\fc\fc\fc\fc\fc\7c\f2\f7\f7\f7\f7\f7\f7\77"
  "\f2\ff\ff\ff\ff\ff\ff\7f\52\55\55\55\55\55\55\55"
)

;; floor and ceiling texture
(data (i32.const 0x500)
  "\00\56\55\55\55\55\55\02\80\56\55\55\55\55\55\0a\a0\55\55\55\55\55\55\29"
  "\68\55\55\55\55\55\55\a5\5a\55\55\55\55\55\55\95\55\55\55\55\55\55\55\55"
  "\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55"
  "\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55"
  "\55\55\55\95\5a\55\55\55\55\55\55\a5\68\55\55\55\55\55\55\29\a0\55\55\55"
  "\55\55\55\0a\80\56\55\55\55\55\55\02\00\56\55\55\55\55\55\0a\80\56\55\55"
  "\55\55\55\29\a0\55\55\55\55\55\55\a5\68\55\55\55\55\55\55\95\5a\55\55\55"
  "\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55"
  "\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55\55"
  "\55\55\55\55\55\55\55\55\5a\55\55\55\55\55\55\95\68\55\55\55\55\55\55\a5"
  "\a0\55\55\55\55\55\55\29\80\56\55\55\55\55\55\0a"
)

;; palette
(data (i32.const 0xd00)
  ;; brick palette
  "\f3\5f\5f\ff\79\0e\0e\ff\00\00\00\ff\9f\25\25\ff"
  ;; ceiling palette
  "\62\8d\c6\ff\81\95\af\ff\62\8d\c6\ff"
  ;; floor palette
  "\81\95\af\ff\b5\b5\b5\ff\b5\b5\b5\ff"
)

;; Position and direction vectors. Direction is updated from angle, which is
;; expressed in radians.
(global $Px (mut f32) (f32.const 0.5))
(global $Py (mut f32) (f32.const 0.5))
(global $angle (mut f32) (f32.const 0.7853981633974483))
(global $t2 (mut f32) (f32.const 0))

(func (export "init")
  ;; initialize distance table:
  ;;   120 / (120 - y) for y in [0, 120)
  (local $y i32)
  (loop $loop
    (f32.store offset=0xe00
      (i32.shl (local.get $y) (i32.const 2))
      (f32.div
        (f32.const 120)
        (f32.sub (f32.const 120) (f32.convert_i32_s (local.get $y)))))

    (br_if $loop
      (i32.lt_s
        (local.tee $y (i32.add (local.get $y) (i32.const 1)))
        (i32.const 120))))

  (call $gen-maze)
)

;; Generate maze using Kruskal's algorithm.
;; See http://weblog.jamisbuck.org/2011/1/3/maze-generation-kruskal-s-algorithm
(func $gen-maze
  (local $i i32)
  (local $x i32)
  (local $y i32)
  (local $wall-addr i32)
  (local $dest-wall-addr i32)
  (local $walls i32)
  (local $fx f32)
  (local $fy f32)

  (local.set $wall-addr (i32.const 0x100))
  (loop $y-loop

    (local.set $x (i32.const 0))
    (loop $x-loop
      ;; Each cell is "owned" by itself at the start.
      (i32.store8 (local.get $i) (local.get $i))

      ;; Add horizontal edge, connecting cell i and i + 1.
      (if (i32.lt_s (local.get $x) (i32.const 11))
        (then
          (i32.store8 (local.get $wall-addr) (local.get $i))
          (i32.store8 offset=1 (local.get $wall-addr) (i32.add (local.get $i) (i32.const 1)))
          (local.set $wall-addr (i32.add (local.get $wall-addr) (i32.const 2)))))

      ;; add vertical edge, connecting cell i and i + 12.
      (if (i32.lt_s (local.get $y) (i32.const 11))
        (then
          (i32.store8 (local.get $wall-addr) (local.get $i))
          (i32.store8 offset=1 (local.get $wall-addr) (i32.add (local.get $i) (i32.const 12)))
          (local.set $wall-addr (i32.add (local.get $wall-addr) (i32.const 2)))))

      ;; increment cell index.
      (local.set $i (i32.add (local.get $i) (i32.const 1)))

      (br_if $x-loop
        (i32.lt_s
          (local.tee $x (i32.add (local.get $x) (i32.const 1)))
          (i32.const 12))))

    (br_if $y-loop
      (i32.lt_s
        (local.tee $y (i32.add (local.get $y) (i32.const 1)))
        (i32.const 12))))

  (local.set $walls (i32.const 264))  ;; 12 * 11 * 2

  ;; randomly choose a wall
  (loop $wall-loop
    (local.set $wall-addr
      (i32.add
        (i32.const 0x100)
        (i32.shl
          (i32.trunc_f32_s
            (f32.mul (call $random) (f32.convert_i32_s (local.get $walls))))
          (i32.const 1))))

    ;; repurpose $x as the left/up cell, and $y as the right/down cell of the
    ;; wall.
    (local.set $x (i32.load8_u (i32.load8_u (local.get $wall-addr))))
    (local.set $y (i32.load8_u (i32.load8_u offset=1 (local.get $wall-addr))))

    ;; if each side of the wall is not part of the same set:
    (if (i32.ne (local.get $x) (local.get $y))
      (then
        ;; remove this wall by copying the last wall over it.
        (local.set $walls (i32.sub (local.get $walls) (i32.const 1)))
        (i32.store16
          (local.get $wall-addr)
          (i32.load16_u offset=0x100
            (i32.shl (local.get $walls) (i32.const 1))))

        ;; replace all cells that contain $y with $x.
        (local.set $i (i32.const 0))
        (loop $remove-loop
          (if (i32.eq (i32.load8_u (local.get $i)) (local.get $y))
            (then (i32.store8 (local.get $i) (local.get $x))))

          (br_if $remove-loop
            (i32.lt_s
              (local.tee $i (i32.add (local.get $i) (i32.const 1)))
              (i32.const 144))))
        ))

    ;; loop until there are exactly 11 * 11 walls.
    (br_if $wall-loop (i32.gt_s (local.get $walls) (i32.const 121))))

  ;; generate walls for use in-game.
  (local.set $wall-addr (i32.const 0x100))
  (local.set $dest-wall-addr (i32.const 0x1050))
  (loop $wall-loop
    ;; Save the right/bottom cell of the wall as $i.
    (local.set $i (i32.load8_u offset=1 (local.get $wall-addr)))

    ;; Get the x,y coordinate of the wall from the cell index.
    ;; Multiply by 2 so each cell is 2x2 units.
    (local.set $fx
      (f32.convert_i32_s
        (i32.shl (i32.rem_s (local.get $i) (i32.const 12)) (i32.const 1))))
    (local.set $fy
      (f32.convert_i32_s
        (i32.shl (i32.div_s (local.get $i) (i32.const 12)) (i32.const 1))))

    (f32.store (local.get $dest-wall-addr) (local.get $fx))
    (f32.store offset=4 (local.get $dest-wall-addr) (local.get $fy))
    (f32.store offset=16 (local.get $dest-wall-addr) (f32.const 2))

    ;; Get the two cells of the wall. If the difference is 1, it must be
    ;; left/right.
    (if (i32.eq
          (i32.sub
            (local.get $i)
            (i32.load8_u (local.get $wall-addr)))
          (i32.const 1))
      ;; left-right wall
      (then
        (local.set $fy (f32.add (local.get $fy) (f32.const 2))))
      ;; top-bottom wall
      (else
        (local.set $fx (f32.add (local.get $fx) (f32.const 2)))))

    (f32.store offset=8 (local.get $dest-wall-addr) (local.get $fx))
    (f32.store offset=12 (local.get $dest-wall-addr) (local.get $fy))

    (local.set $dest-wall-addr
      (i32.add (local.get $dest-wall-addr) (i32.const 20)))

    (br_if $wall-loop
      (i32.lt_s
        (local.tee $wall-addr (i32.add (local.get $wall-addr) (i32.const 2)))
        (i32.const 0x1f2)))))   ;; 0x100 + 11 * 11 * 2

(func $fmod (param $x f32) (param $y f32) (result f32)
  (f32.sub
    (local.get $x)
    (f32.mul
      (f32.trunc
        (f32.div
          (local.get $x)
          (local.get $y)))
      (local.get $y))))

;; Ray/line segment intersection. see https://rootllama.wordpress.com/2014/06/20/ray-line-segment-intersection-test-in-2d/
;;
;;   ray is defined by [Px,Py] -> [Dx,Dy].
;;   line segment is [sx,sy] -> [ex,ey].
;;
;;   Returns distance to the segment, or inf if it doesn't hit.
(func $ray-line
      (param $Dx f32) (param $Dy f32)
      (param $sx f32) (param $sy f32) (param $ex f32) (param $ey f32)
      (result f32)
  (local $v1x f32)
  (local $v1y f32)
  (local $v2x f32)
  (local $v2y f32)
  (local $v3x f32)
  (local $v3y f32)
  (local $inv-v2.v3 f32)
  (local $t1 f32)
  (local $t2 f32)

  ;; v1 = P - s
  (local.set $v1x (f32.sub (global.get $Px) (local.get $sx)))
  (local.set $v1y (f32.sub (global.get $Py) (local.get $sy)))

  ;; v2 = e - s
  (local.set $v2x (f32.sub (local.get $ex) (local.get $sx)))
  (local.set $v2y (f32.sub (local.get $ey) (local.get $sy)))

  ;; v3 = (-Dy, Dx)
  (local.set $v3x (f32.neg (local.get $Dy)))
  (local.set $v3y (local.get $Dx))

  (local.set $inv-v2.v3
    (f32.div
      (f32.const 1)
      (f32.add
        (f32.mul (local.get $v2x) (local.get $v3x))
        (f32.mul (local.get $v2y) (local.get $v3y)))))

  ;; t2 is intersection "time" between s and e.
  (local.set $t2
    (f32.mul
      (f32.add
        (f32.mul (local.get $v1x) (local.get $v3x))
        (f32.mul (local.get $v1y) (local.get $v3y)))
      (local.get $inv-v2.v3)))

  ;; t2 must be between [0, 1].
  (if
    (i32.and
      (f32.ge (local.get $t2) (f32.const 0))
      (f32.le (local.get $t2) (f32.const 1)))
    (then
      ;; t1 is distance along ray.
      (local.set $t1
        (f32.mul
          (f32.sub
            (f32.mul (local.get $v2x) (local.get $v1y))
            (f32.mul (local.get $v1x) (local.get $v2y)))
          (local.get $inv-v2.v3)))

      (if (f32.ge (local.get $t1) (f32.const 0))
        (then
          ;; return intersection time as global.
          (global.set $t2 (local.get $t2))
          (return (local.get $t1))))))

  (f32.const inf))

(func $ray-walls (param $ray-x f32) (param $ray-y f32) (result f32)
  (local $dist f32)
  (local $mindist f32)
  (local $mint2 f32)
  (local $wall i32)

  (local.set $mindist (f32.const inf))
  (local.set $wall (i32.const 0x1000))
  (loop $wall-loop
    (local.set $dist
      (call $ray-line
        (local.get $ray-x)
        (local.get $ray-y)
        (f32.load (local.get $wall))
        (f32.load offset=4 (local.get $wall))
        (f32.load offset=8 (local.get $wall))
        (f32.load offset=12 (local.get $wall))))

    (if (f32.lt (local.get $dist) (local.get $mindist))
      (then
        (local.set $mindist (local.get $dist))
        (local.set $mint2
          (f32.mul (global.get $t2) (f32.load offset=16 (local.get $wall))))))

    (br_if $wall-loop
      (i32.lt_s
        (local.tee $wall (i32.add (local.get $wall) (i32.const 20)))
        (i32.const 0x19c4))))

  (global.set $t2 (local.get $mint2))
  (local.get $mindist))

(func $scale-frac-i32 (param $x f32) (result i32)
  (local.set $x (f32.add (local.get $x) (local.get $x)))
  (i32.trunc_f32_s
    (f32.mul
      (f32.sub (local.get $x) (f32.floor (local.get $x)))
      (f32.const 32))))

(func $texture
      (param $tex-addr i32) (param $pal-addr i32)
      (param $u f32) (param $v f32)
      (result i32)
  (local $iu i32)
  (local $iv i32)

  (local.set $iu (call $scale-frac-i32 (local.get $u)))
  (local.set $iv (call $scale-frac-i32 (local.get $v)))

  ;; read 2bpp color, then index into palette
  (i32.load
    (i32.add
      (local.get $pal-addr)
      (i32.shl
        (i32.and
          (i32.shr_u
            (i32.load8_u
              (i32.add
                (local.get $tex-addr)
                (i32.add (i32.shl (local.get $iv) (i32.const 3))
                         (i32.shr_u (local.get $iu) (i32.const 2)))))
            (i32.shl (i32.and (local.get $iu) (i32.const 3)) (i32.const 1)))
          (i32.const 3))
        (i32.const 2)))))

(func $draw-ceiling-and-floor
      (param $top-addr i32) (param $height i32) (param $ray-x f32) (param $ray-y f32)
      (result i32)
  (local $bot-addr i32)
  (local $dist-addr i32)
  (local $dist f32)
  (local $u f32)
  (local $v f32)

  (local.set $bot-addr (i32.add (local.get $top-addr) (i32.const 307200)))

  (if (i32.gt_s (local.get $height) (i32.const 0))
    (then
      (loop $loop
        ;; update distance
        (local.set $dist (f32.load offset=0xe00 (local.get $dist-addr)))
        (local.set $dist-addr (i32.add (local.get $dist-addr) (i32.const 4)))

        ;; find UV using distance table
        (local.set $u
          (f32.add (global.get $Px) (f32.mul (local.get $ray-x) (local.get $dist))))
        (local.set $v
          (f32.add (global.get $Py) (f32.mul (local.get $ray-y) (local.get $dist))))

        ;; draw ceiling (decrement after)
        (i32.store offset=0x3000
          (local.get $top-addr)
          (call $texture
            (i32.const 0x500) (i32.const 0xd10)
            (local.get $u) (local.get $v)))
        (local.set $top-addr (i32.add (local.get $top-addr) (i32.const 1280)))

        ;; draw-floor (decrement before)
        (local.set $bot-addr (i32.sub (local.get $bot-addr) (i32.const 1280)))
        (i32.store offset=0x3000
          (local.get $bot-addr)
          (call $texture
            (i32.const 0x500) (i32.const 0xd1c)
            (local.get $u) (local.get $v)))


        (br_if $loop
          (local.tee $height (i32.sub (local.get $height) (i32.const 1)))))))
  (local.get $top-addr))

(func $draw-wall (param $addr i32) (param $height i32)
  (local $u f32)
  (local $v f32)
  (local $dv f32)

  (local.set $u (global.get $t2))
  (local.set $dv (f32.div (f32.const 1) (f32.convert_i32_s (local.get $height))))

  (if (i32.gt_s (local.get $height) (i32.const 240))
    (then
      (local.set $v
        (f32.mul
          (local.get $dv)
          (f32.convert_i32_s
            (i32.shr_s
              (i32.sub (local.get $height) (i32.const 240))
              (i32.const 1)))))
      (local.set $height (i32.const 240))))

  (if (local.get $height)
    (then
      (loop $loop
        (i32.store offset=0x3000 (local.get $addr)
          (call $texture
            (i32.const 0x400) (i32.const 0xd00)
            (local.get $u) (local.get $v)))
        (local.set $v (f32.add (local.get $v) (local.get $dv)))
        (local.set $addr (i32.add (local.get $addr) (i32.const 1280)))
        (br_if $loop
          (local.tee $height (i32.sub (local.get $height) (i32.const 1))))))))

(func (export "run")
  (local $x i32)
  (local $wall i32)
  (local $xproj f32)
  (local $Dx f32)
  (local $Dy f32)
  (local $height i32)
  (local $addr i32)
  (local $rotate f32)

  (local $ray-x f32)
  (local $ray-y f32)

  ;; rotate
  (local.set $rotate
    (f32.mul
      (f32.convert_i32_s
        (i32.sub
          (i32.load8_u (i32.const 0xc00))
          (i32.load8_u (i32.const 0xc01))))
      (f32.const 0.04)))
  (global.set $angle
    (call $fmod (f32.add (global.get $angle) (local.get $rotate))
                (f32.const 6.283185307179586)))

  (local.set $Dx (call $sin (global.get $angle)))
  (local.set $Dy (call $sin (f32.add (global.get $angle) (f32.const 1.5707963267948966))))

  ;; move forward
  (if (i32.load8_u (i32.const 0xc02))
    (then
      (global.set $Px
        (f32.add (global.get $Px) (f32.mul (local.get $Dx) (f32.const 0.05))))
      (global.set $Py
        (f32.add (global.get $Py) (f32.mul (local.get $Dy) (f32.const 0.05))))))

  ;; Loop for each column.
  (loop $x-loop
    (local.set $xproj
      (f32.div
        (f32.convert_i32_s (i32.sub (local.get $x) (i32.const 160)))
        (f32.const 160)))

    ;; Shoot a ray against a wall. Use rays projected onto screen plane.
    (local.set $ray-x
      (f32.add (local.get $Dx) (f32.mul (local.get $xproj) (f32.neg (local.get $Dy)))))
    (local.set $ray-y
      (f32.add (local.get $Dy) (f32.mul (local.get $xproj) (local.get $Dx))))

    (local.set $height
      (i32.trunc_f32_s
        (f32.div
          (f32.const 240)
          (call $ray-walls (local.get $ray-x) (local.get $ray-y)))))

    ;; draw ceiling and floor
    (local.set $addr
      (call $draw-ceiling-and-floor
        (i32.shl (local.get $x) (i32.const 2))
        (i32.shr_s (i32.sub (i32.const 240) (local.get $height)) (i32.const 1))
        (local.get $ray-x) (local.get $ray-y)))

    ;; draw wall
    (call $draw-wall (local.get $addr) (local.get $height))

    ;; loop on x
    (br_if $x-loop
      (i32.lt_s
        (local.tee $x (i32.add (local.get $x) (i32.const 1)))
        (i32.const 320))))
)
