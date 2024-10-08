; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
;
; Test numbering remains continuous across:
; - InstCombine/fast-basictest.ll
; - PhaseOrdering/fast-basictest.ll
; - PhaseOrdering/fast-reassociate-gvn.ll
; - Reassociate/fast-basictest.ll
;
; RUN: opt < %s -passes=instcombine -S | FileCheck %s

; With reassociation, constant folding can eliminate the 12 and -12 constants.

define float @test1(float %arg) {
; CHECK-LABEL: @test1(
; CHECK-NEXT:    [[T2:%.*]] = fneg fast float [[ARG:%.*]]
; CHECK-NEXT:    ret float [[T2]]
;
  %t1 = fsub fast float -1.200000e+01, %arg
  %t2 = fadd fast float %t1, 1.200000e+01
  ret float %t2
}

; Check again using the minimal subset of FMF.
; Both 'reassoc' and 'nsz' are required.
define float @test1_minimal(float %arg) {
; CHECK-LABEL: @test1_minimal(
; CHECK-NEXT:    [[T2:%.*]] = fneg reassoc nsz float [[ARG:%.*]]
; CHECK-NEXT:    ret float [[T2]]
;
  %t1 = fsub reassoc nsz float -1.200000e+01, %arg
  %t2 = fadd reassoc nsz float %t1, 1.200000e+01
  ret float %t2
}

; Verify the fold is not done with only 'reassoc' ('nsz' is required).
define float @test1_reassoc(float %arg) {
; CHECK-LABEL: @test1_reassoc(
; CHECK-NEXT:    [[T1:%.*]] = fsub reassoc float -1.200000e+01, [[ARG:%.*]]
; CHECK-NEXT:    [[T2:%.*]] = fadd reassoc float [[T1]], 1.200000e+01
; CHECK-NEXT:    ret float [[T2]]
;
  %t1 = fsub reassoc float -1.200000e+01, %arg
  %t2 = fadd reassoc float %t1, 1.200000e+01
  ret float %t2
}

; ((a + (-3)) + b) + 3 -> a + b
; That only works with both instcombine and reassociate passes enabled.
; Check that instcombine is not enough.

define float @test2(float %reg109, float %reg1111) {
; CHECK-LABEL: @test2(
; CHECK-NEXT:    [[REG115:%.*]] = fadd fast float [[REG109:%.*]], -3.000000e+01
; CHECK-NEXT:    [[REG116:%.*]] = fadd fast float [[REG115]], [[REG1111:%.*]]
; CHECK-NEXT:    [[REG117:%.*]] = fadd fast float [[REG116]], 3.000000e+01
; CHECK-NEXT:    ret float [[REG117]]
;
  %reg115 = fadd fast float %reg109, -3.000000e+01
  %reg116 = fadd fast float %reg115, %reg1111
  %reg117 = fadd fast float %reg116, 3.000000e+01
  ret float %reg117
}

define float @test2_no_FMF(float %reg109, float %reg1111) {
; CHECK-LABEL: @test2_no_FMF(
; CHECK-NEXT:    [[REG115:%.*]] = fadd float [[REG109:%.*]], -3.000000e+01
; CHECK-NEXT:    [[REG116:%.*]] = fadd float [[REG115]], [[REG1111:%.*]]
; CHECK-NEXT:    [[REG117:%.*]] = fadd float [[REG116]], 3.000000e+01
; CHECK-NEXT:    ret float [[REG117]]
;
  %reg115 = fadd float %reg109, -3.000000e+01
  %reg116 = fadd float %reg115, %reg1111
  %reg117 = fadd float %reg116, 3.000000e+01
  ret float %reg117
}

define float @test2_reassoc(float %reg109, float %reg1111) {
; CHECK-LABEL: @test2_reassoc(
; CHECK-NEXT:    [[REG115:%.*]] = fadd reassoc float [[REG109:%.*]], -3.000000e+01
; CHECK-NEXT:    [[REG116:%.*]] = fadd reassoc float [[REG115]], [[REG1111:%.*]]
; CHECK-NEXT:    [[REG117:%.*]] = fadd reassoc float [[REG116]], 3.000000e+01
; CHECK-NEXT:    ret float [[REG117]]
;
  %reg115 = fadd reassoc float %reg109, -3.000000e+01
  %reg116 = fadd reassoc float %reg115, %reg1111
  %reg117 = fadd reassoc float %reg116, 3.000000e+01
  ret float %reg117
}

; (-X)*Y + Z -> Z-X*Y

define float @test7(float %X, float %Y, float %Z) {
; CHECK-LABEL: @test7(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul fast float [[X:%.*]], [[Y:%.*]]
; CHECK-NEXT:    [[C:%.*]] = fsub fast float [[Z:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[C]]
;
  %A = fsub fast float 0.0, %X
  %B = fmul fast float %A, %Y
  %C = fadd fast float %B, %Z
  ret float %C
}

define float @test7_unary_fneg(float %X, float %Y, float %Z) {
; CHECK-LABEL: @test7_unary_fneg(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul fast float [[X:%.*]], [[Y:%.*]]
; CHECK-NEXT:    [[C:%.*]] = fsub fast float [[Z:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[C]]
;
  %A = fneg fast float %X
  %B = fmul fast float %A, %Y
  %C = fadd fast float %B, %Z
  ret float %C
}

define float @test7_reassoc_nsz(float %X, float %Y, float %Z) {
; CHECK-LABEL: @test7_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul reassoc nsz float [[X:%.*]], [[Y:%.*]]
; CHECK-NEXT:    [[C:%.*]] = fsub reassoc nsz float [[Z:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[C]]
;
  %A = fsub reassoc nsz float 0.0, %X
  %B = fmul reassoc nsz float %A, %Y
  %C = fadd reassoc nsz float %B, %Z
  ret float %C
}

; Verify that fold is not done only with 'reassoc' ('nsz' is required)
define float @test7_reassoc(float %X, float %Y, float %Z) {
; CHECK-LABEL: @test7_reassoc(
; CHECK-NEXT:    [[A:%.*]] = fsub reassoc float 0.000000e+00, [[X:%.*]]
; CHECK-NEXT:    [[B:%.*]] = fmul reassoc float [[A]], [[Y:%.*]]
; CHECK-NEXT:    [[C:%.*]] = fadd reassoc float [[B]], [[Z:%.*]]
; CHECK-NEXT:    ret float [[C]]
;
  %A = fsub reassoc float 0.0, %X
  %B = fmul reassoc float %A, %Y
  %C = fadd reassoc float %B, %Z
  ret float %C
}

define float @test8(float %X) {
; CHECK-LABEL: @test8(
; CHECK-NEXT:    [[Z:%.*]] = fmul fast float [[X:%.*]], 9.400000e+01
; CHECK-NEXT:    ret float [[Z]]
;
  %Y = fmul fast float %X, 4.700000e+01
  %Z = fadd fast float %Y, %Y
  ret float %Z
}

; Check again with 'reassoc' and 'nsz' ('nsz' not technically required).
define float @test8_reassoc_nsz(float %X) {
; CHECK-LABEL: @test8_reassoc_nsz(
; CHECK-NEXT:    [[Z:%.*]] = fmul reassoc nsz float [[X:%.*]], 9.400000e+01
; CHECK-NEXT:    ret float [[Z]]
;
  %Y = fmul reassoc nsz float %X, 4.700000e+01
  %Z = fadd reassoc nsz float %Y, %Y
  ret float %Z
}

; TODO: This doesn't require 'nsz'.  It should fold to X * 94.0
define float @test8_reassoc(float %X) {
; CHECK-LABEL: @test8_reassoc(
; CHECK-NEXT:    [[Y:%.*]] = fmul reassoc float [[X:%.*]], 4.700000e+01
; CHECK-NEXT:    [[Z:%.*]] = fadd reassoc float [[Y]], [[Y]]
; CHECK-NEXT:    ret float [[Z]]
;
  %Y = fmul reassoc float %X, 4.700000e+01
  %Z = fadd reassoc float %Y, %Y
  ret float %Z
}

; Side note: (x + x + x) and (3*x) each have only a single rounding.  So
; transforming x+x+x to 3*x is always safe, even without any FMF.
; To avoid that special-case, we have the addition of 'x' four times, here.

define float @test9(float %X) {
; CHECK-LABEL: @test9(
; CHECK-NEXT:    [[W:%.*]] = fmul fast float [[X:%.*]], 4.000000e+00
; CHECK-NEXT:    ret float [[W]]
;
  %Y = fadd fast float %X ,%X
  %Z = fadd fast float %Y, %X
  %W = fadd fast float %Z, %X
  ret float %W
}

; Check again with 'reassoc' and 'nsz' ('nsz' not technically required).
define float @test9_reassoc_nsz(float %X) {
; CHECK-LABEL: @test9_reassoc_nsz(
; CHECK-NEXT:    [[W:%.*]] = fmul reassoc nsz float [[X:%.*]], 4.000000e+00
; CHECK-NEXT:    ret float [[W]]
;
  %Y = fadd reassoc nsz float %X ,%X
  %Z = fadd reassoc nsz float %Y, %X
  %W = fadd reassoc nsz float %Z, %X
  ret float %W
}

; TODO: This doesn't require 'nsz'.  It should fold to 4 * x
define float @test9_reassoc(float %X) {
; CHECK-LABEL: @test9_reassoc(
; CHECK-NEXT:    [[Y:%.*]] = fadd reassoc float [[X:%.*]], [[X]]
; CHECK-NEXT:    [[Z:%.*]] = fadd reassoc float [[Y]], [[X]]
; CHECK-NEXT:    [[W:%.*]] = fadd reassoc float [[Z]], [[X]]
; CHECK-NEXT:    ret float [[W]]
;
  %Y = fadd reassoc float %X ,%X
  %Z = fadd reassoc float %Y, %X
  %W = fadd reassoc float %Z, %X
  ret float %W
}

define float @test10(float %W) {
; CHECK-LABEL: @test10(
; CHECK-NEXT:    [[Z:%.*]] = fmul fast float [[W:%.*]], 3.810000e+02
; CHECK-NEXT:    ret float [[Z]]
;
  %X = fmul fast float %W, 127.0
  %Y = fadd fast float %X ,%X
  %Z = fadd fast float %Y, %X
  ret float %Z
}

; Check again using the minimal subset of FMF.
; Check again with 'reassoc' and 'nsz' ('nsz' not technically required).
define float @test10_reassoc_nsz(float %W) {
; CHECK-LABEL: @test10_reassoc_nsz(
; CHECK-NEXT:    [[Z:%.*]] = fmul reassoc nsz float [[W:%.*]], 3.810000e+02
; CHECK-NEXT:    ret float [[Z]]
;
  %X = fmul reassoc nsz float %W, 127.0
  %Y = fadd reassoc nsz float %X ,%X
  %Z = fadd reassoc nsz float %Y, %X
  ret float %Z
}

; TODO: This doesn't require 'nsz'.  It should fold to W*381.0.
define float @test10_reassoc(float %W) {
; CHECK-LABEL: @test10_reassoc(
; CHECK-NEXT:    [[X:%.*]] = fmul reassoc float [[W:%.*]], 1.270000e+02
; CHECK-NEXT:    [[Y:%.*]] = fadd reassoc float [[X]], [[X]]
; CHECK-NEXT:    [[Z:%.*]] = fadd reassoc float [[Y]], [[X]]
; CHECK-NEXT:    ret float [[Z]]
;
  %X = fmul reassoc float %W, 127.0
  %Y = fadd reassoc float %X ,%X
  %Z = fadd reassoc float %Y, %X
  ret float %Z
}

define float @test11(float %X) {
; CHECK-LABEL: @test11(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul fast float [[X:%.*]], 3.000000e+00
; CHECK-NEXT:    [[Z:%.*]] = fsub fast float 6.000000e+00, [[TMP1]]
; CHECK-NEXT:    ret float [[Z]]
;
  %A = fsub fast float 1.000000e+00, %X
  %B = fsub fast float 2.000000e+00, %X
  %C = fsub fast float 3.000000e+00, %X
  %Y = fadd fast float %A ,%B
  %Z = fadd fast float %Y, %C
  ret float %Z
}

; Check again with 'reassoc' and 'nsz' ('nsz' not technically required).
define float @test11_reassoc_nsz(float %X) {
; CHECK-LABEL: @test11_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul reassoc nsz float [[X:%.*]], 3.000000e+00
; CHECK-NEXT:    [[Z:%.*]] = fsub reassoc nsz float 6.000000e+00, [[TMP1]]
; CHECK-NEXT:    ret float [[Z]]
;
  %A = fsub reassoc nsz float 1.000000e+00, %X
  %B = fsub reassoc nsz float 2.000000e+00, %X
  %C = fsub reassoc nsz float 3.000000e+00, %X
  %Y = fadd reassoc nsz float %A ,%B
  %Z = fadd reassoc nsz float %Y, %C
  ret float %Z
}

; TODO: This doesn't require 'nsz'.  It should fold to (6.0 - 3.0*x)
define float @test11_reassoc(float %X) {
; CHECK-LABEL: @test11_reassoc(
; CHECK-NEXT:    [[A:%.*]] = fsub reassoc float 1.000000e+00, [[X:%.*]]
; CHECK-NEXT:    [[B:%.*]] = fsub reassoc float 2.000000e+00, [[X]]
; CHECK-NEXT:    [[C:%.*]] = fsub reassoc float 3.000000e+00, [[X]]
; CHECK-NEXT:    [[Y:%.*]] = fadd reassoc float [[A]], [[B]]
; CHECK-NEXT:    [[Z:%.*]] = fadd reassoc float [[Y]], [[C]]
; CHECK-NEXT:    ret float [[Z]]
;
  %A = fsub reassoc float 1.000000e+00, %X
  %B = fsub reassoc float 2.000000e+00, %X
  %C = fsub reassoc float 3.000000e+00, %X
  %Y = fadd reassoc float %A ,%B
  %Z = fadd reassoc float %Y, %C
  ret float %Z
}

define float @test12(float %X1, float %X2, float %X3) {
; CHECK-LABEL: @test12(
; CHECK-NEXT:    [[TMP1:%.*]] = fsub fast float [[X3:%.*]], [[X2:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul fast float [[TMP1]], [[X1:%.*]]
; CHECK-NEXT:    ret float [[D]]
;
  %A = fsub fast float 0.000000e+00, %X1
  %B = fmul fast float %A, %X2   ; -X1*X2
  %C = fmul fast float %X1, %X3  ; X1*X3
  %D = fadd fast float %B, %C    ; -X1*X2 + X1*X3 -> X1*(X3-X2)
  ret float %D
}

define float @test12_unary_fneg(float %X1, float %X2, float %X3) {
; CHECK-LABEL: @test12_unary_fneg(
; CHECK-NEXT:    [[TMP1:%.*]] = fsub fast float [[X3:%.*]], [[X2:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul fast float [[TMP1]], [[X1:%.*]]
; CHECK-NEXT:    ret float [[D]]
;
  %A = fneg fast float %X1
  %B = fmul fast float %A, %X2   ; -X1*X2
  %C = fmul fast float %X1, %X3  ; X1*X3
  %D = fadd fast float %B, %C    ; -X1*X2 + X1*X3 -> X1*(X3-X2)
  ret float %D
}

define float @test12_reassoc_nsz(float %X1, float %X2, float %X3) {
; CHECK-LABEL: @test12_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fsub reassoc nsz float [[X3:%.*]], [[X2:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul reassoc nsz float [[TMP1]], [[X1:%.*]]
; CHECK-NEXT:    ret float [[D]]
;
  %A = fsub reassoc nsz float 0.000000e+00, %X1
  %B = fmul reassoc nsz float %A, %X2   ; -X1*X2
  %C = fmul reassoc nsz float %X1, %X3  ; X1*X3
  %D = fadd reassoc nsz float %B, %C    ; -X1*X2 + X1*X3 -> X1*(X3-X2)
  ret float %D
}

; TODO: check if 'nsz' is technically required. Currently the optimization
; is not done with only 'reassoc' without 'nsz'.
define float @test12_reassoc(float %X1, float %X2, float %X3) {
; CHECK-LABEL: @test12_reassoc(
; CHECK-NEXT:    [[A:%.*]] = fsub reassoc float 0.000000e+00, [[X1:%.*]]
; CHECK-NEXT:    [[B:%.*]] = fmul reassoc float [[A]], [[X2:%.*]]
; CHECK-NEXT:    [[C:%.*]] = fmul reassoc float [[X1]], [[X3:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fadd reassoc float [[B]], [[C]]
; CHECK-NEXT:    ret float [[D]]
;
  %A = fsub reassoc float 0.000000e+00, %X1
  %B = fmul reassoc float %A, %X2   ; -X1*X2
  %C = fmul reassoc float %X1, %X3  ; X1*X3
  %D = fadd reassoc float %B, %C    ; -X1*X2 + X1*X3 -> X1*(X3-X2)
  ret float %D
}

; (x1 * 47) + (x2 * -47) => (x1 - x2) * 47
; That only works with both instcombine and reassociate passes enabled.
; Check that instcombine is not enough.

define float @test13(float %X1, float %X2) {
; CHECK-LABEL: @test13(
; CHECK-NEXT:    [[B:%.*]] = fmul fast float [[X1:%.*]], 4.700000e+01
; CHECK-NEXT:    [[C:%.*]] = fmul fast float [[X2:%.*]], -4.700000e+01
; CHECK-NEXT:    [[D:%.*]] = fadd fast float [[B]], [[C]]
; CHECK-NEXT:    ret float [[D]]
;
  %B = fmul fast float %X1, 47.   ; X1*47
  %C = fmul fast float %X2, -47.  ; X2*-47
  %D = fadd fast float %B, %C     ; X1*47 + X2*-47 -> 47*(X1-X2)
  ret float %D
}

define float @test13_reassoc_nsz(float %X1, float %X2) {
; CHECK-LABEL: @test13_reassoc_nsz(
; CHECK-NEXT:    [[B:%.*]] = fmul reassoc nsz float [[X1:%.*]], 4.700000e+01
; CHECK-NEXT:    [[C:%.*]] = fmul reassoc nsz float [[X2:%.*]], -4.700000e+01
; CHECK-NEXT:    [[D:%.*]] = fadd reassoc nsz float [[B]], [[C]]
; CHECK-NEXT:    ret float [[D]]
;
  %B = fmul reassoc nsz float %X1, 47.   ; X1*47
  %C = fmul reassoc nsz float %X2, -47.  ; X2*-47
  %D = fadd reassoc nsz float %B, %C     ; X1*47 + X2*-47 -> 47*(X1-X2)
  ret float %D
}

define float @test13_reassoc(float %X1, float %X2) {
; CHECK-LABEL: @test13_reassoc(
; CHECK-NEXT:    [[B:%.*]] = fmul reassoc float [[X1:%.*]], 4.700000e+01
; CHECK-NEXT:    [[C:%.*]] = fmul reassoc float [[X2:%.*]], -4.700000e+01
; CHECK-NEXT:    [[D:%.*]] = fadd reassoc float [[B]], [[C]]
; CHECK-NEXT:    ret float [[D]]
;
  %B = fmul reassoc float %X1, 47.   ; X1*47
  %C = fmul reassoc float %X2, -47.  ; X2*-47
  %D = fadd reassoc float %B, %C     ; X1*47 + X2*-47 -> 47*(X1-X2)
  ret float %D
}

define float @test14(float %arg) {
; CHECK-LABEL: @test14(
; CHECK-NEXT:    [[T2:%.*]] = fmul fast float [[ARG:%.*]], 1.440000e+02
; CHECK-NEXT:    ret float [[T2]]
;
  %t1 = fmul fast float 1.200000e+01, %arg
  %t2 = fmul fast float %t1, 1.200000e+01
  ret float %t2
}

define float @test14_reassoc(float %arg) {
; CHECK-LABEL: @test14_reassoc(
; CHECK-NEXT:    [[T2:%.*]] = fmul reassoc float [[ARG:%.*]], 1.440000e+02
; CHECK-NEXT:    ret float [[T2]]
;
  %t1 = fmul reassoc float 1.200000e+01, %arg
  %t2 = fmul reassoc float %t1, 1.200000e+01
  ret float %t2
}

; (b+(a+1234))+-a -> b+1234
; That only works with both instcombine and reassociate passes enabled.
; Check that instcombine is not enough.

define float @test15(float %b, float %a) {
; CHECK-LABEL: @test15(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd fast float [[A:%.*]], 1.234000e+03
; CHECK-NEXT:    [[TMP2:%.*]] = fadd fast float [[B:%.*]], [[TMP1]]
; CHECK-NEXT:    [[TMP3:%.*]] = fsub fast float [[TMP2]], [[A]]
; CHECK-NEXT:    ret float [[TMP3]]
;
  %1 = fadd fast float %a, 1234.0
  %2 = fadd fast float %b, %1
  %3 = fsub fast float 0.0, %a
  %4 = fadd fast float %2, %3
  ret float %4
}

define float @test15_unary_fneg(float %b, float %a) {
; CHECK-LABEL: @test15_unary_fneg(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd fast float [[A:%.*]], 1.234000e+03
; CHECK-NEXT:    [[TMP2:%.*]] = fadd fast float [[B:%.*]], [[TMP1]]
; CHECK-NEXT:    [[TMP3:%.*]] = fsub fast float [[TMP2]], [[A]]
; CHECK-NEXT:    ret float [[TMP3]]
;
  %1 = fadd fast float %a, 1234.0
  %2 = fadd fast float %b, %1
  %3 = fneg fast float %a
  %4 = fadd fast float %2, %3
  ret float %4
}

define float @test15_reassoc_nsz(float %b, float %a) {
; CHECK-LABEL: @test15_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd reassoc nsz float [[A:%.*]], 1.234000e+03
; CHECK-NEXT:    [[TMP2:%.*]] = fadd reassoc nsz float [[B:%.*]], [[TMP1]]
; CHECK-NEXT:    [[TMP3:%.*]] = fsub reassoc nsz float [[TMP2]], [[A]]
; CHECK-NEXT:    ret float [[TMP3]]
;
  %1 = fadd reassoc nsz float %a, 1234.0
  %2 = fadd reassoc nsz float %b, %1
  %3 = fsub reassoc nsz float 0.0, %a
  %4 = fadd reassoc nsz float %2, %3
  ret float %4
}

define float @test15_reassoc(float %b, float %a) {
; CHECK-LABEL: @test15_reassoc(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd reassoc float [[A:%.*]], 1.234000e+03
; CHECK-NEXT:    [[TMP2:%.*]] = fadd reassoc float [[B:%.*]], [[TMP1]]
; CHECK-NEXT:    [[TMP3:%.*]] = fsub reassoc float 0.000000e+00, [[A]]
; CHECK-NEXT:    [[TMP4:%.*]] = fadd reassoc float [[TMP2]], [[TMP3]]
; CHECK-NEXT:    ret float [[TMP4]]
;
  %1 = fadd reassoc float %a, 1234.0
  %2 = fadd reassoc float %b, %1
  %3 = fsub reassoc float 0.0, %a
  %4 = fadd reassoc float %2, %3
  ret float %4
}

; X*-(Y*Z) -> X*-1*Y*Z
; That only works with both instcombine and reassociate passes enabled.
; Check that instcombine is not enough.

define float @test16(float %a, float %b, float %z) {
; CHECK-LABEL: @test16(
; CHECK-NEXT:    [[C:%.*]] = fneg fast float [[Z:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul fast float [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[E:%.*]] = fmul fast float [[D]], [[C]]
; CHECK-NEXT:    [[G:%.*]] = fmul fast float [[E]], -1.234500e+04
; CHECK-NEXT:    ret float [[G]]
;
  %c = fsub fast float 0.000000e+00, %z
  %d = fmul fast float %a, %b
  %e = fmul fast float %c, %d
  %f = fmul fast float %e, 1.234500e+04
  %g = fsub fast float 0.000000e+00, %f
  ret float %g
}

define float @test16_unary_fneg(float %a, float %b, float %z) {
; CHECK-LABEL: @test16_unary_fneg(
; CHECK-NEXT:    [[C:%.*]] = fneg fast float [[Z:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul fast float [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[E:%.*]] = fmul fast float [[D]], [[C]]
; CHECK-NEXT:    [[G:%.*]] = fmul fast float [[E]], -1.234500e+04
; CHECK-NEXT:    ret float [[G]]
;
  %c = fneg fast float %z
  %d = fmul fast float %a, %b
  %e = fmul fast float %c, %d
  %f = fmul fast float %e, 1.234500e+04
  %g = fneg fast float %f
  ret float %g
}

define float @test16_reassoc_nsz(float %a, float %b, float %z) {
; CHECK-LABEL: @test16_reassoc_nsz(
; CHECK-NEXT:    [[C:%.*]] = fneg reassoc nsz float [[Z:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul reassoc nsz float [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[E:%.*]] = fmul reassoc nsz float [[D]], [[C]]
; CHECK-NEXT:    [[G:%.*]] = fmul reassoc nsz float [[E]], -1.234500e+04
; CHECK-NEXT:    ret float [[G]]
;
  %c = fsub reassoc nsz float 0.000000e+00, %z
  %d = fmul reassoc nsz float %a, %b
  %e = fmul reassoc nsz float %c, %d
  %f = fmul reassoc nsz float %e, 1.234500e+04
  %g = fsub reassoc nsz float 0.000000e+00, %f
  ret float %g
}

define float @test16_reassoc(float %a, float %b, float %z) {
; CHECK-LABEL: @test16_reassoc(
; CHECK-NEXT:    [[C:%.*]] = fsub reassoc float 0.000000e+00, [[Z:%.*]]
; CHECK-NEXT:    [[D:%.*]] = fmul reassoc float [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[E:%.*]] = fmul reassoc float [[C]], [[D]]
; CHECK-NEXT:    [[F:%.*]] = fmul reassoc float [[E]], 1.234500e+04
; CHECK-NEXT:    [[G:%.*]] = fsub reassoc float 0.000000e+00, [[F]]
; CHECK-NEXT:    ret float [[G]]
;
  %c = fsub reassoc float 0.000000e+00, %z
  %d = fmul reassoc float %a, %b
  %e = fmul reassoc float %c, %d
  %f = fmul reassoc float %e, 1.234500e+04
  %g = fsub reassoc float 0.000000e+00, %f
  ret float %g
}

define float @test17(float %a, float %b, float %z) {
; CHECK-LABEL: @test17(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul fast float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[F:%.*]] = fmul fast float [[A:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul fast float %z, 4.000000e+01
  %c = fsub fast float 0.000000e+00, %d
  %e = fmul fast float %a, %c
  %f = fsub fast float 0.000000e+00, %e
  ret float %f
}

define float @test17_unary_fneg(float %a, float %b, float %z) {
; CHECK-LABEL: @test17_unary_fneg(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul fast float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[F:%.*]] = fmul fast float [[A:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul fast float %z, 4.000000e+01
  %c = fneg fast float %d
  %e = fmul fast float %a, %c
  %f = fneg fast float %e
  ret float %f
}

define float @test17_reassoc_nsz(float %a, float %b, float %z) {
; CHECK-LABEL: @test17_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul reassoc nsz float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[F:%.*]] = fmul reassoc nsz float [[A:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul reassoc nsz float %z, 4.000000e+01
  %c = fsub reassoc nsz float 0.000000e+00, %d
  %e = fmul reassoc nsz float %a, %c
  %f = fsub reassoc nsz float 0.000000e+00, %e
  ret float %f
}

; Verify the fold is not done with only 'reassoc' ('nsz' is required).
define float @test17_reassoc(float %a, float %b, float %z) {
; CHECK-LABEL: @test17_reassoc(
; CHECK-NEXT:    [[D:%.*]] = fmul reassoc float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[C:%.*]] = fsub reassoc float 0.000000e+00, [[D]]
; CHECK-NEXT:    [[E:%.*]] = fmul reassoc float [[A:%.*]], [[C]]
; CHECK-NEXT:    [[F:%.*]] = fsub reassoc float 0.000000e+00, [[E]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul reassoc float %z, 4.000000e+01
  %c = fsub reassoc float 0.000000e+00, %d
  %e = fmul reassoc float %a, %c
  %f = fsub reassoc float 0.000000e+00, %e
  ret float %f
}

; fneg of fneg is an identity operation, so no FMF are needed to remove those instructions.

define float @test17_unary_fneg_no_FMF(float %a, float %b, float %z) {
; CHECK-LABEL: @test17_unary_fneg_no_FMF(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[F:%.*]] = fmul float [[A:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul float %z, 4.000000e+01
  %c = fneg float %d
  %e = fmul float %a, %c
  %f = fneg float %e
  ret float %f
}

define float @test17_reassoc_unary_fneg(float %a, float %b, float %z) {
; CHECK-LABEL: @test17_reassoc_unary_fneg(
; CHECK-NEXT:    [[TMP1:%.*]] = fmul reassoc float [[Z:%.*]], 4.000000e+01
; CHECK-NEXT:    [[F:%.*]] = fmul reassoc float [[A:%.*]], [[TMP1]]
; CHECK-NEXT:    ret float [[F]]
;
  %d = fmul reassoc float %z, 4.000000e+01
  %c = fneg reassoc float %d
  %e = fmul reassoc float %a, %c
  %f = fneg reassoc float %e
  ret float %f
}

; With sub reassociation, constant folding can eliminate the 12 and -12 constants.
; That only works with both instcombine and reassociate passes enabled.
; Check that instcombine is not enough.

define float @test18(float %A, float %B) {
; CHECK-LABEL: @test18(
; CHECK-NEXT:    [[X:%.*]] = fadd fast float [[A:%.*]], -1.200000e+01
; CHECK-NEXT:    [[Y:%.*]] = fsub fast float [[X]], [[B:%.*]]
; CHECK-NEXT:    [[Z:%.*]] = fadd fast float [[Y]], 1.200000e+01
; CHECK-NEXT:    ret float [[Z]]
;
  %X = fadd fast float -1.200000e+01, %A
  %Y = fsub fast float %X, %B
  %Z = fadd fast float %Y, 1.200000e+01
  ret float %Z
}

define float @test18_reassoc(float %A, float %B) {
; CHECK-LABEL: @test18_reassoc(
; CHECK-NEXT:    [[X:%.*]] = fadd reassoc float [[A:%.*]], -1.200000e+01
; CHECK-NEXT:    [[Y:%.*]] = fsub reassoc float [[X]], [[B:%.*]]
; CHECK-NEXT:    [[Z:%.*]] = fadd reassoc float [[Y]], 1.200000e+01
; CHECK-NEXT:    ret float [[Z]]
;
  %X = fadd reassoc float -1.200000e+01, %A
  %Y = fsub reassoc float %X, %B
  %Z = fadd reassoc float %Y, 1.200000e+01
  ret float %Z
}

; With sub reassociation, constant folding can eliminate the uses of %a.

define float @test19(float %a, float %b, float %c) nounwind  {
; CHECK-LABEL: @test19(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd fast float [[B:%.*]], [[C:%.*]]
; CHECK-NEXT:    [[T7:%.*]] = fneg fast float [[TMP1]]
; CHECK-NEXT:    ret float [[T7]]
;
  %t3 = fsub fast float %a, %b
  %t5 = fsub fast float %t3, %c
  %t7 = fsub fast float %t5, %a
  ret float %t7
}

define float @test19_reassoc_nsz(float %a, float %b, float %c) nounwind  {
; CHECK-LABEL: @test19_reassoc_nsz(
; CHECK-NEXT:    [[TMP1:%.*]] = fadd reassoc nsz float [[B:%.*]], [[C:%.*]]
; CHECK-NEXT:    [[T7:%.*]] = fneg reassoc nsz float [[TMP1]]
; CHECK-NEXT:    ret float [[T7]]
;
  %t3 = fsub reassoc nsz float %a, %b
  %t5 = fsub reassoc nsz float %t3, %c
  %t7 = fsub reassoc nsz float %t5, %a
  ret float %t7
}

; Verify the fold is not done with only 'reassoc' ('nsz' is required).
define float @test19_reassoc(float %a, float %b, float %c) nounwind  {
; CHECK-LABEL: @test19_reassoc(
; CHECK-NEXT:    [[T3:%.*]] = fsub reassoc float [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[T5:%.*]] = fsub reassoc float [[T3]], [[C:%.*]]
; CHECK-NEXT:    [[T7:%.*]] = fsub reassoc float [[T5]], [[A]]
; CHECK-NEXT:    ret float [[T7]]
;
  %t3 = fsub reassoc float %a, %b
  %t5 = fsub reassoc float %t3, %c
  %t7 = fsub reassoc float %t5, %a
  ret float %t7
}
