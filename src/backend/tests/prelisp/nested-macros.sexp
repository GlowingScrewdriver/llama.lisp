(c-lisp
  (define ((__add_dot4x4 void)
           (k int)
           (a (ptr float))
           (lda int)
           (b (ptr float))
           (ldb int)
           (c (ptr float))
           (ldc int))
    (store (ptradd c (add 0 (mul 0 ldc))) 0)
    (for ((set p 0) (lt p k) (set p (add p 1)))
        ,(muladd
            ,(arr-idx c ldc 0 0)
            ,(arr-idx a ldc 0 p)
            ,(arr-idx b ldc p 0))
    (ret))))
