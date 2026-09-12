; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stack-symbol-ordering=0 -stop-after=prolog-epilog -o - %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stack-symbol-ordering=0 -O0 -stop-after=prolog-epilog -o - %s | FileCheck %s

; The allocas are declared in the reverse of the stack protector layout order
; (large arrays, small arrays, address-taken variables, everything else), so
; the offsets only come out in that order if the layout was applied. Offsets
; are checked relative to %scalar, the first object in the stack list.

declare void @use(ptr, ptr, ptr)
declare void @sink(i32)

; CHECK-LABEL: name: layout_strong
; CHECK:       stackProtector:  ''
; CHECK-NEXT:  stackProtectorLayoutOnly: true
; CHECK:       stack:
; CHECK-NEXT:    - { id: 0, name: scalar, type: default, offset: [[#%d,SCALAR:]],
; CHECK:         - { id: 1, name: addrof, type: default, offset: [[#SCALAR+4]],
; CHECK:         - { id: 2, name: small, type: default, offset: [[#SCALAR+8]],
; CHECK:         - { id: 3, name: large, type: default, offset: [[#SCALAR+12]],
define void @layout_strong(i32 %n) sspstrong "stack-protector-layout-only" {
  %scalar = alloca i32, align 4
  %addrof = alloca i32, align 4
  %small = alloca [4 x i8], align 4
  %large = alloca [16 x i8], align 16
  store i32 %n, ptr %scalar
  call void @use(ptr %large, ptr %small, ptr %addrof)
  %v = load i32, ptr %scalar
  call void @sink(i32 %v)
  ret void
}

; With ssp only the large array is protected; the rest keeps its index order.
; CHECK-LABEL: name: layout_ssp
; CHECK:       stackProtector:  ''
; CHECK-NEXT:  stackProtectorLayoutOnly: true
; CHECK:       stack:
; CHECK-NEXT:    - { id: 0, name: scalar, type: default, offset: [[#%d,SCALAR:]],
; CHECK:         - { id: 1, name: addrof, type: default, offset: [[#SCALAR-4]],
; CHECK:         - { id: 2, name: small, type: default, offset: [[#SCALAR-8]],
; CHECK:         - { id: 3, name: large, type: default, offset: [[#SCALAR+4]],
define void @layout_ssp(i32 %n) ssp "stack-protector-layout-only" {
  %scalar = alloca i32, align 4
  %addrof = alloca i32, align 4
  %small = alloca [4 x i8], align 4
  %large = alloca [16 x i8], align 16
  store i32 %n, ptr %scalar
  call void @use(ptr %large, ptr %small, ptr %addrof)
  %v = load i32, ptr %scalar
  call void @sink(i32 %v)
  ret void
}

; sspreq with nothing to lay out: no stack protector is inserted and the layout
; is not applied.
; CHECK-LABEL: name: req_empty
; CHECK:       stackProtector:  ''
; CHECK-NEXT:  stackProtectorLayoutOnly: false
define void @req_empty() sspreq "stack-protector-layout-only" {
  ret void
}

; Without a stack protector attribute the objects keep their index order.
; CHECK-LABEL: name: control
; CHECK:       stackProtector:  ''
; CHECK-NEXT:  stackProtectorLayoutOnly: false
; CHECK:       stack:
; CHECK-NEXT:    - { id: 0, name: scalar, type: default, offset: [[#%d,SCALAR:]],
; CHECK:         - { id: 1, name: addrof, type: default, offset: [[#SCALAR-4]],
; CHECK:         - { id: 2, name: small, type: default, offset: [[#SCALAR-8]],
; CHECK:         - { id: 3, name: large, type: default, offset: -{{[0-9]+}},
define void @control(i32 %n) {
  %scalar = alloca i32, align 4
  %addrof = alloca i32, align 4
  %small = alloca [4 x i8], align 4
  %large = alloca [16 x i8], align 16
  store i32 %n, ptr %scalar
  call void @use(ptr %large, ptr %small, ptr %addrof)
  %v = load i32, ptr %scalar
  call void @sink(i32 %v)
  ret void
}

; Without the attribute a stack protector is still inserted.
; CHECK-LABEL: name: cookie
; CHECK:       stackProtector:  '%stack.{{[0-9]+}}.StackGuardSlot'
; CHECK-NEXT:  stackProtectorLayoutOnly: false
define void @cookie(i32 %n) sspstrong {
  %scalar = alloca i32, align 4
  %addrof = alloca i32, align 4
  %small = alloca [4 x i8], align 4
  %large = alloca [16 x i8], align 16
  store i32 %n, ptr %scalar
  call void @use(ptr %large, ptr %small, ptr %addrof)
  %v = load i32, ptr %scalar
  call void @sink(i32 %v)
  ret void
}
