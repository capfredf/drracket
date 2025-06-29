#lang racket/unit

(require racket/class
         string-constants
         racket/gui/base
         framework
         browser/external
         setup/getinfo
         drracket/private/drsig
         "../acks.rkt"
         "local-member-names.rkt"
         "frame-icon.rkt"
         pict/snip pict)

(import [prefix drracket:unit: drracket:unit^]
        [prefix drracket:frame: drracket:frame^]
        [prefix drracket:language-configuration: drracket:language-configuration/internal^]
        [prefix help-desk: drracket:help-desk^]
        [prefix drracket:tools: drracket:tools^])
(export drracket:app^)

(define about-frame%
  (class (drracket:frame:basics-mixin (frame:standard-menus-mixin frame:basic%))
    (init-field main-text got-closed)
    (inherit close)
    (define/override (on-subwindow-char receiver event)
      (cond
        [(equal? (send event get-key-code) 'escape)
         (close)]
        [else
         (super on-subwindow-char receiver event)]))
    (define/augment (on-close)
      (inner (void) on-close)
      (got-closed))
    (define/private (edit-menu:do const)
      (send main-text do-edit-operation const))
    [define/override file-menu:create-revert? (λ () #f)]
    [define/override file-menu:create-save? (λ () #f)]
    [define/override file-menu:create-save-as? (λ () #f)]
    [define/override file-menu:between-close-and-quit (λ (x) (void))]
    [define/override edit-menu:between-redo-and-cut (λ (x) (void))]
    [define/override edit-menu:between-select-all-and-find (λ (x) (void))]
    [define/override edit-menu:copy-callback (λ (menu evt) (edit-menu:do 'copy))]
    [define/override edit-menu:select-all-callback (λ (menu evt) (edit-menu:do 'select-all))]
    [define/override edit-menu:create-find? (λ () #f)]
    (super-new
     (label (string-constant about-drscheme-frame-title)))))


(define (same-widths items)
  (let ([max-width (apply max (map (λ (x) (send x get-width)) items))])
    (for-each (λ (x) (send x min-width max-width)) items)))

(define (same-heights items)
  (let ([max-height (apply max (map (λ (x) (send x get-height)) items))])
    (for-each (λ (x) (send x min-height max-height)) items)))

(define wrap-edit%
  (class (editor:standard-style-list-mixin
          text:hide-caret/selection%)
    (inherit begin-edit-sequence end-edit-sequence
             get-max-width find-snip position-location)
    (define/augment (on-set-size-constraint)
      (begin-edit-sequence)
      (let ([snip (find-snip 1 'after-or-none)])
        (when (is-a? snip editor-snip%)
          (send (send snip get-editor) begin-edit-sequence)))
      (inner (void) on-set-size-constraint))
    (define/augment (after-set-size-constraint)
      (inner (void) after-set-size-constraint)
      (let ([width (get-max-width)]
            [snip (find-snip 1 'after-or-none)])
        (when (is-a? snip editor-snip%)
          (let ([b (box 0)])
            (position-location 1 b #f #f #t)
            (let ([new-width (- width 4 (unbox b))])
              (when (> new-width 0)
                (send snip resize new-width
                      17) ; smallest random number
                (send snip set-max-height 'none))))
          (send (send snip get-editor) end-edit-sequence)))
      (end-edit-sequence))
    (super-new)))

(define (get-plt-pict)
  (dc
   (λ (dc dx dy)
     (define smoothing (send dc get-smoothing))
     (define pen (send dc get-pen))
     (define brush (send dc get-brush))
     (define-values (sx sy) (send dc get-scale))
     (define-values (ox oy) (send dc get-origin))
     (send dc set-origin (+ ox dx) (+ oy dy))
     (send dc set-scale mb-scale-factor mb-scale-factor)
     (send dc set-smoothing 'smoothed)
     (send dc set-pen "black" 1 'transparent)
     (when (preferences:get 'framework:white-on-black?)
       (define old-clip (send dc get-clipping-region))
       (define rgn (new region% [dc dc]))
       (define pen (send dc get-pen))
       (define brush (send dc get-brush))
       (define offset 4) ;; this offset seems to make a tight fit around the actual logo
       (send rgn set-ellipse
             offset offset
             (- mb-plain-width offset offset)
             (- mb-plain-height offset offset))
       (send dc set-clipping-region rgn)
       (send dc set-brush "white" 'solid)
       (send dc set-pen "black" 1 'transparent)
       (send dc draw-rectangle 0 0  mb-plain-width  mb-plain-height)
       (send dc set-pen pen)
       (send dc set-brush brush)
       (send dc set-clipping-region old-clip))
     (mb-main-drawing dc)
     (send dc set-pen pen)
     (send dc set-brush brush)
     (send dc set-smoothing smoothing)
     (send dc set-scale sx sy)
     (send dc set-origin ox oy))
   mb-flat-width mb-flat-height))

(define (about-drscheme)
  (define e (make-object wrap-edit%))
  (define main-text (make-object wrap-edit%))
  (define plt-pict (get-plt-pict))
  (define plt-snip (new pict-snip% [pict plt-pict]))
  (define editor-snip (make-object editor-snip% e #f))
  (define remove-callback-defined? #f)
  (define f
    (new about-frame%
         [main-text main-text]
         [got-closed
          (λ () (when remove-callback-defined? (remove-callback)))]))
  (define main-panel (send f get-area-container))
  (define editor-canvas (make-object canvas:color% main-panel))
  (define button-panel (make-object horizontal-panel% main-panel))
  (define top (make-object style-delta% 'change-alignment 'top))
  (define sl (send e get-style-list))
  (define usual-style
    (send sl new-named-style "drracket:about base style"
          (send sl find-named-style
                (editor:get-default-color-style-name))))

  (define d-usual (make-object style-delta% 'change-family 'decorative))
  (send d-usual set-weight-on 'normal)
  (send d-usual set-delta 'change-underline #f)
  (send usual-style set-delta d-usual)

  (define dr-style
    (send sl new-named-style "drracket:about dr style"
          usual-style))
  (define d-dr (make-object style-delta%))
  (send d-dr set-delta 'change-bold)
  (send dr-style set-delta d-dr)

  (define clickback-style
    (send sl new-named-style "drracket:about clickback"
          usual-style))
  (send clickback-style set-delta
        (gui-utils:get-clickback-delta
         (preferences:get 'framework:white-on-black?)))

  (define (insert/clickback str clickback)
    (send e change-style clickback-style)
    (define before (send e get-start-position))
    (send e insert str)
    (define after (send e get-start-position))
    (send e set-clickback before after
          (λ (a b c) (clickback)))
    (send e change-style usual-style))

  (define (insert-url/external-browser str url)
    (insert/clickback str (λ () (send-url url))))


  (send* editor-canvas
    (set-editor main-text)
    (stretchable-width #t)
    (stretchable-height #t))

  (send* editor-canvas
    (min-width (inexact->exact (floor (+ (* 5/2 (pict-width plt-pict)) 50))))
    (min-height (inexact->exact (round (+ (pict-height plt-pict) 50)))))

  (send* e
    (change-style dr-style)
    (insert (format (string-constant welcome-to-drscheme-version/language)
                    (version:version)
                    (this-language)))
    (change-style usual-style))

  (send e insert " by ")

  (insert-url/external-browser "PLT" "http://racket-lang.org/")

  (send* e
    (insert ".\n\n")
    (insert (get-authors))
    (insert "\n\nFor licensing information see "))

  (insert/clickback "our software license"
                    (λ () (help-desk:goto-plt-license)))

  (send* e
    (insert ".\n\nBased on:\n  ")
    (insert (banner)))

  (let ([tools (sort (drracket:tools:get-successful-tools)
                     (lambda (a b)
                       (string<? (path->string (drracket:tools:successful-tool-spec a))
                                 (path->string (drracket:tools:successful-tool-spec b)))))])
    (unless (null? tools)
      (let loop ([actions1 '()] [actions2 '()] [tools tools])
        (if (pair? tools)
            (let* ([successful-tool (car tools)]
                   [name (drracket:tools:successful-tool-name successful-tool)]
                   [spec (drracket:tools:successful-tool-spec successful-tool)]
                   [bm   (drracket:tools:successful-tool-bitmap successful-tool)]
                   [url  (drracket:tools:successful-tool-url successful-tool)])
              (define (action)
                (send e insert "  ")
                (when bm
                  (send* e
                    (insert (make-object image-snip% bm))
                    (insert #\space)))
                (let ([name (or name (format "~a" spec))])
                  (cond [url  (insert-url/external-browser name url)]
                        [else (send* e
                                (change-style usual-style)
                                (insert name)
                                (change-style usual-style))]))
                (send e insert #\newline))
              (if name
                  (loop (cons action actions1) actions2 (cdr tools))
                  (loop actions1 (cons action actions2) (cdr tools))))
            (begin (send e insert "\nInstalled tools:\n")
                   (for-each (λ (act) (act)) (reverse actions1))
                   ;; (send e insert "Installed anonymous tools:\n")
                   (for-each (λ (act) (act)) (reverse actions2)))))))

  (send e insert "\n")
  (send e insert (get-translating-acks))

  (let* ([docs-button (new button%
                           [label (string-constant help-desk)]
                           [parent button-panel]
                           [callback (λ (x y) (help-desk:help-desk))])])
    (send docs-button focus))
  (send button-panel stretchable-height #f)
  (send button-panel set-alignment 'center 'center)

  (define (update-wob v)
    (define sl (editor:get-standard-style-list))
    (send sl begin-style-change-sequence)
    (define color (if v "white" "black"))
    (send usual-style get-delta d-usual)
    (send d-usual set-delta-foreground color)
    (send usual-style set-delta d-usual)
    (send dr-style get-delta d-dr)
    (send d-dr set-delta-foreground color)
    (send dr-style set-delta d-dr)
    (send clickback-style set-delta (gui-utils:get-clickback-delta v))
    (send sl end-style-change-sequence))
  (define remove-callback
    (preferences:add-callback
     'framework:white-on-black?
     (λ (p v)
       (update-wob v))))
  (update-wob (preferences:get 'framework:white-on-black?))
  (set! remove-callback-defined? #t)

  (send* e
    (auto-wrap #t)
    (set-autowrap-bitmap #f))
  (send* main-text
    (set-autowrap-bitmap #f)
    (auto-wrap #t)
    (insert plt-snip)
    (insert editor-snip)
    (change-style top 0 2)
    (hide-caret #t))
  (send editor-snip use-style-background #t)
  (send f reflow-container)

  (send* main-text
    (set-position 1)
    (scroll-to-position 0)
    (lock #t))

  (send* e
    (set-position 0)
    (scroll-to-position 0)
    (lock #t))

  (when (eq? (system-type) 'macosx)
    ;; otherwise, the focus is the tour button, as above
    (send editor-canvas focus))

  (send f show #t)
  f)


;                                       
;                                       
;                                       
;                ;   ;   ;              
;                    ;                  
;           ;        ;       ;          
;   ;    ; ;;;;  ;   ;   ;  ;;;; ;     ;
;   ;    ;  ;    ;   ;   ;   ;    ;   ; 
;   ;    ;  ;    ;   ;   ;   ;    ;   ; 
;   ;    ;  ;    ;   ;   ;   ;     ;  ; 
;   ;    ;  ;    ;   ;   ;   ;     ; ;  
;   ;   ;;  ;    ;   ;   ;   ;      ;;  
;    ;;; ;   ;;  ;   ;   ;    ;;    ;   
;                                   ;   
;                                   ;   
;                                  ;    


;; switch-language-to : (is-a?/c top-level-window<%>) symbol -> void
;; doesn't return if the language changes
(define (switch-language-to parent other-language)
  (define-values (other-are-you-sure other-cancel other-accept-and-quit)
    (let loop ([languages (all-languages)]
               [are-you-sures (string-constants are-you-sure-you-want-to-switch-languages)]
               [cancels (string-constants cancel)]
               [accept-and-quits (if (eq? (system-type) 'windows)
                                     (string-constants accept-and-exit)
                                     (string-constants accept-and-quit))])
      (cond
        [(null? languages) (error 'app.rkt ".1")]
        [(equal? other-language (car languages))
         (values (car are-you-sures)
                 (car cancels)
                 (car accept-and-quits))]
        [else (loop (cdr languages)
                    (cdr are-you-sures)
                    (cdr cancels)
                    (cdr accept-and-quits))])))
  (define dialog (make-object dialog% (string-constant drscheme) parent 400))
  (define (make-section are-you-sure cancel-label quit-label)
    (define text (make-object text:hide-caret/selection%))
    (define ec (instantiate editor-canvas% ()
                 (parent dialog)
                 (editor text)
                 (style '(no-hscroll))))
    (define bp (instantiate horizontal-panel% ()
                 (parent dialog)
                 (alignment '(right center))))
    (define-values (quit cancel)
      (gui-utils:ok/cancel-buttons
       bp
       (λ (x y)
         (set! cancelled? #f)
         (send dialog show #f))
       (λ (x y)
         (send dialog show #f))
       quit-label
       cancel-label))
    (send ec set-line-count 3)
    (send text auto-wrap #t)
    (send text set-autowrap-bitmap #f)
    (send text insert are-you-sure)
    (send text set-position 0 0))
  (define cancelled? #t)

  (make-section other-are-you-sure
                other-cancel
                other-accept-and-quit)

  (make-section (string-constant are-you-sure-you-want-to-switch-languages)
                (string-constant cancel)
                (if (eq? (system-type) 'windows)
                    (string-constant accept-and-exit)
                    (string-constant accept-and-quit)))

  (send dialog show #t)

  (unless cancelled?
    (let ([set-language? #t])
      (exit:insert-on-callback
       (λ ()
         (when set-language?
           (set-language-pref other-language))))
      (exit:exit)
      (set! set-language? #f))))

(define (add-important-urls-to-help-menu help-menu additional)
  (let* ([important-urls
          (instantiate menu% ()
            (parent help-menu)
            (label (string-constant web-materials)))]
         [tool-urls-menu
          (instantiate menu% ()
            (parent help-menu)
            (label (string-constant tool-web-sites)))]
         [add
          (λ (name url . parent)
            (instantiate menu-item% ()
              (label name)
              (parent (if (null? parent) important-urls (car parent)))
              (callback
               (λ (x y)
                 (send-url url)))))])
    (add (string-constant plt-homepage) "http://racket-lang.org/")
    (add (string-constant pbd-homepage) "http://programbydesign.org/")
    (add |How to Design Programs| "http://htdp.org/")

    (for-each (λ (tool)
                (cond [(drracket:tools:successful-tool-url tool)
                       =>
                       (λ (url)
                         (add (drracket:tools:successful-tool-name tool) url tool-urls-menu))]))
              (drracket:tools:get-successful-tools))

    (let loop ([additional additional])
      (cond
        [(pair? additional)
         (let ([x (car additional)])
           (when (and (pair? x)
                      (pair? (cdr x))
                      (null? (cddr x))
                      (string? (car x))
                      (string? (cadr x)))
             (add (car x) (cadr x))))
         (loop (cdr additional))]
        [else (void)]))))

(define (add-language-items-to-help-menu help-menu)
  (let ([added-any? #f])
    (for-each (λ (native-lang-string language)
                (unless (equal? (this-language) language)
                  (unless added-any?
                    (make-object separator-menu-item% help-menu)
                    (set! added-any? #t))
                  (instantiate menu-item% ()
                    (label native-lang-string)
                    (parent help-menu)
                    (callback (λ (x1 x2) (switch-language-to #f language))))))
              good-interact-strings
              languages-with-good-labels)))

(define-values (languages-with-good-labels good-interact-strings)
  (let loop ([langs (all-languages)]
             [strs (string-constants interact-with-drscheme-in-language)]
             [good-langs '()]
             [good-strs '()])
    (cond
      [(null? strs) (values (reverse good-langs)
                            (reverse good-strs))]
      [else (let ([str (car strs)]
                  [lang (car langs)])
              (if (andmap (λ (char) (send normal-control-font screen-glyph-exists? char #t))
                          (string->list str))
                  (loop (cdr langs)
                        (cdr strs)
                        (cons lang good-langs)
                        (cons str good-strs))
                  (loop (cdr langs) (cdr strs) good-langs good-strs)))])))
