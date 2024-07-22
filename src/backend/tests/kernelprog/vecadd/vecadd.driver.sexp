(c-lisp
    (define-struct CUfunction
        (dummy (ptr int)))
    (define-struct CUdeviceptr
        (dummy (ptr int))
        (dummy2 (ptr int)))
    (define-struct CUmodule
        (dummy (ptr int)))
    (define-struct CUcontext
        (dummy (ptr int)))
    (define-struct CUdevice
        (dummy int)
        (dummy2 int))

    ;; Constants that we can't currently define in C-Lisp
    ;; TODO
    (define ((reading_stdin_msg (ptr int8))))
    (define ((eof_char int8)))
    (define ((null_char int8)))
    (define ((kernel_name_str (ptr int8))))
    (define ((error_status_msg (ptr int8))))
    (define ((max_err_msg (ptr int8))))
    (define ((null_ptr (ptr int))))

    ;; External linkage
    (define ((puts int) (s (ptr int8))))
    (define ((print void) (n int)))
    (define ((fprint void) (n float)))
    (define ((getchar int8)))
    (define ((exit void) (status int)))
    (define ((malloc (ptr float)) (sz int)))
    (define ((rand float)))
    ; From <math.h> (-lm)
    (define ((fabsf float) (a float)))
    (define ((fmaxf float) (a float) (b float)))
    (define ((free void) (p (ptr float))))
    ; From <cuda.h> (-lcuda)
    (define ((cuInit int) (flags int)))
    (define ((cuDeviceGetCount int) (n (ptr int))))
    (define ((cuDeviceGet int)
        ;(dev (ptr (struct CUdevice)))
        (dev (ptr int))
        (ordinal int)))
    (define ((cuCtxCreate int)
        (context (ptr (struct CUcontext)))
        (flags int)
        (device int)))
    (define ((cuModuleLoadData int)
        (module (ptr (struct CUmodule)))
        (data (ptr int8))))
    (define ((cuModuleGetFunction int)
        (func (ptr (struct CUfunction)))
        (module (struct CUmodule))
        (name (ptr int8))))

    (define ((cuMemAlloc int) (pntr (ptr (struct CUdeviceptr))) (n int)))
    ;(define ((cuMemAlloc int) (pntr (ptr int)) (n int)))
    (define ((cuMemFree int) (pntr (struct CUdeviceptr))))
    (define ((cuMemcpyHtoD int)
        (d_pntr (struct CUdeviceptr))
        (h_pntr (ptr float))
        (sz int)))
    (define ((cuMemcpyDtoH int)
        (h_pntr (ptr float))
        (d_pntr (struct CUdeviceptr))
        (sz int)))
    (define ((cuLaunchKernel int)
        (func (struct CUfunction))
        (grdx int) (grdy int) (grdz int)
        (blkx int) (blky int) (blkz int)
        (shmem int) (stream (ptr int)) (params (ptr (ptr (struct CUdeviceptr)))) (exopts (ptr int))))
    (define ((cuCtxSynchronize int)))
    (define ((cuModuleUnload int) (mod (struct CUmodule))))
    (define ((cuCtxDestroy int) (ctx (struct CUcontext))))

    (define ((ref_kernel void) (a (ptr float)) (b (ptr float)) (res (ptr float)) (N int))
        (declare i int)
        (for ((set i 0)
              (lt i N)
              (set i (add i 1)))
            (store (ptradd res i)
                   (fadd (load (ptradd a i))
                         (load (ptradd b i))))))

    ;; TODO [macro] [string]: macro the call to this function
    (define ((error_check void) (res int) (call_str (ptr int8)))
        (if (ne res 0)
            ((call puts (call error_status_msg))
             (call puts call_str)
             (call print res)
             (call exit res))))

    (define ((read_module void) (buf (ptr int8)))
        ;; TODO [string]: define message string here
        (call puts (call reading_stdin_msg))

        (declare c int8)
        (while (ne (set c (call getchar))
                   ;; TODO [macro]: use 'EOF' inline
                   (call eof_char))
                (store buf c)
                (set buf (ptradd buf 1)))
        ;; TODO: set null character inline
        (store buf (call null_char))
        (ret))

    ;; [WIP]
    (define ((main void))

        (declare i int)
        (declare devCount int) (set devCount 0)
        (declare device int) (set device 0)
        (declare context (struct CUcontext))
        (declare module (struct CUmodule))
        (declare kernel_func (struct CUfunction))

        ;; CUDA initialization and context creation
        ;; TODO [macro]: Wrap API calls with error-checking macros
        (call cuInit 0)
        (call cuDeviceGetCount (ptr-to devCount))
        (call cuDeviceGet (ptr-to device) 0)
        (call cuCtxCreate (ptr-to context) 0 device)

        ;; Load the kernel image and get a handle to the kernel function
        (declare kernel_ptx (ptr int8))
        (set kernel_ptx (alloc int8 4000))
        (call read_module kernel_ptx)
        (call cuModuleLoadData (ptr-to module) kernel_ptx)
        ;; TODO [string]: define kernel name inline
        (call cuModuleGetFunction (ptr-to kernel_func) module (call kernel_name_str))

        ;; Allocate input and result
        (declare N int)
        (set N 32)
        (declare sz int) (set sz (mul N 4))
        (declare a (ptr float))
        (declare b (ptr float))
        (declare res_device (ptr float))
        (declare res_host (ptr float))
        (set a (call malloc sz))
        (set b (call malloc sz))
        (set res_device (call malloc sz))
        (set res_host (call malloc sz))

        (for ((set i 0)
              (lt i N)
              (set i (add i 1)))
            (store (ptradd a i) (call rand))
            (store (ptradd b i) (call rand)))

        ;; Run the reference implementation
        (call ref_kernel a b res_host N)

        ;; Copy data to device
        ; CUdeviceptr <=> (ptr int)
        (declare dev_a (struct CUdeviceptr))
        (declare dev_b (struct CUdeviceptr))
        (declare dev_res (struct CUdeviceptr))
        (call cuMemAlloc (ptr-to dev_a) sz)
        (call cuMemAlloc (ptr-to dev_b) sz)
        (call cuMemAlloc (ptr-to dev_res) sz)
        (call cuMemcpyHtoD dev_a a sz)
        (call cuMemcpyHtoD dev_b b sz)

        ;; Launch the kernel and wait
        ; Array of CUdeviceptr *
        (declare KernelParams (ptr (ptr (struct CUdeviceptr))))
        (set KernelParams (alloc (ptr (struct CUdeviceptr)) 3))
        (store KernelParams (ptr-to dev_a))
        (store (ptradd KernelParams 1) (ptr-to dev_b))
        (store (ptradd KernelParams 2) (ptr-to dev_res))
        (declare BlockSize int) (set BlockSize 32)
        (declare GridSize int)
        (set GridSize (div (sub (add N BlockSize) 1)
                            BlockSize))
        (call print (call cuLaunchKernel kernel_func
                             ; Grid sizes X, Y, Z
                             GridSize 1 1
                             ; Block sizes X, Y, Z
                             BlockSize 1 1
                             ; Shared mem size, stream id, kernel params, extra options
                             ; TODO: specify NULL inline
                             0 (call null_ptr) KernelParams (call null_ptr)))
        (call print (call cuCtxSynchronize))

        ;; Retieve and verify results
        (call cuMemcpyDtoH res_device dev_res sz)
        (declare max_err float) (set max_err 0.0)
        (for ((set i 0)
              (lt i N)
              (set i (add i 1)))
            (declare diff float)
            (set diff (fsub (load (ptradd res_host i))
                            (load (ptradd res_device i))))
            (set max_err
                 (call fmaxf max_err (call fabsf diff))))
        (call puts (call max_err_msg))
        (call fprint max_err)

        ;; Cleanup
        (call free a)
        (call free b)
        (call free res_host)
        (call free res_device)
        (call cuMemFree dev_a)
        (call cuMemFree dev_b)
        (call cuMemFree dev_res)
        (call cuModuleUnload module)
        (call cuCtxDestroy context)
        (ret)))
