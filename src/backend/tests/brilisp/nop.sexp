(brilisp
    (define ((print int) (n int)))

    (define ((main void))
        (nop)
        (set (v int) (const 5))
        (nop)
        (set (tmp void) (call print v))
        (nop)
        (ret)
        ))
