#lang racket

(require "structure-data.rkt")
(require "static-text.rkt")
(require "paths.rkt")
(require "filters.rkt")
(require scribble/core)
(require scribble/base)
(require scribble/decode)
(require scribble/html-properties)
(require file/sha1)

(provide generate-document)

(define (generate-paper-list ps left-color right-color)
  (if (empty? ps)
      (para "Nothing here!")
      (tabular 
       #:sep (hspace 1)
       #:style (style #f
                      (list (table-columns (list (style #f '(right)) ;; NB: the style properties are found in table-cells
                                                 (style #f '(center))
                                                 (style #f '(left))
                                                 (style #f '(center))
                                                 (style #f '(left))
                                                 (style #f '(center))
                                                 (style #f (list 'center
                                                                 (attributes
                                                                  `((style . ,(string-append "background-color: #"
                                                                                             (color-list->color-string left-color)))))))
                                                 (style #f '(center))
                                                 (style #f (list 'center
                                                                 (attributes
                                                                  `((style . ,(string-append "background-color: #"
                                                                                             (color-list->color-string right-color)))))))))))
       (map (lambda (p)
              (list (paper-group p)
                    (paper-authors p)
                    (paper-title p)
                    (hyperlink 
                     (build-notes-link (paper-path p))
                     "notes")
                    (list
                     (if (disputed? p)
                         (hyperlink (dispute-link (paper-path p)) "dispute!")
                         " ")
                     (linebreak)
                     (if (cleared? p)
                         (hyperlink (cleared-link (paper-path p)) "cleared?")
                         " ")
                     (linebreak)
                     (if (problem? p)
                         (hyperlink (problem-link (paper-path p)) "problem?")
                         " ")
                     (linebreak)
                     (if (misclassified? p)
                         (hyperlink (misclass-link (paper-path p)) "misclassified")
                         " ")
                     )))
            ps))))

(define (color-string->color-list s)
  (bytes->list (hex-string->bytes s)))
(define (color-list->color-string l)
  (bytes->hex-string (list->bytes l)))

#| Colors from http://www.colourlovers.com/palette/3292950/Candy_colors by averagegirl |#

(define bad-color (color-string->color-list "F2BAD6"))
(define good-color (color-string->color-list "6BEEE2"))
(define neutral-color (color-string->color-list "D1FCFC"))
(define progress-color (color-string->color-list "BEE2F4"))
(define misclass-color (color-string->color-list "DDB7E2"))

(struct sec (title filter left-col-color right-col-color))

(define report-sections
  (list (sec "Purported Not Building; Disputed; Not Checked"
             (and-filters not-building? disputed? not-checked?) bad-color neutral-color)
        (sec "Purported Building; Disputed; Not Checked"
             (and-filters building? disputed? not-checked?) good-color neutral-color)
        (sec "Conflicting Checks!"
             (and-filters cleared? problem?) neutral-color bad-color)
        (sec "Misclassified"
             misclassified? neutral-color misclass-color)
        ;; don't use disputed? for the next two, because people may have checked
        ;; without a formal dispute filed!
        (sec "Purported Not Building But Found Building"
             (and-filters not-building? cleared? not-problem?) bad-color good-color)
        (sec "Purported Building But Found Not Building"
             (and-filters building? not-cleared? problem?) good-color bad-color)
        (sec "Purported Not Building; Confirmed"
             (and-filters not-building? not-cleared? problem?) bad-color bad-color)
        (sec "Purported Building; Confirmed"
             (and-filters building? cleared? not-problem?) good-color good-color)
        (sec "All Others Purported Not Building"
             (and-filters not-building? not-misclassified? not-disputed? not-checked? not-problem?) bad-color neutral-color)
        (sec "All Other Purported Building"
             (and-filters building? not-misclassified? not-disputed? not-checked? not-problem?) good-color neutral-color)))

(define (generate-document papers)
  (define (gen-filtered f color) (generate-paper-list (filter f papers) color))
  (define (make-section title relevant-papers left-color right-color)
    (list (section title " (" (number->string (length relevant-papers)) ")")
          (generate-paper-list (shuffle relevant-papers) left-color right-color)))
  (define paper-count (length papers))
  (decode
   (list
    (title "Examining ``Reproducibility in Computer Science''")
    (section "What We Are Doing")
    top-matter
    (section "Progress")
    (tabular #:sep (hspace 1)
             #:style (style #f
                            (list (background-color-property progress-color)
                                  (table-columns (list (style #f '(right)) ;; NB: the style properties are found in table-cells
                                                       (style #f '(center))
                                                       (style #f '(right))
                                                       (style #f '(center))
                                                       (style #f '(left))))))
             (map
              (lambda (s)
                (define these-papers-count (length (filter (sec-filter s) papers)))
                (define ratio (floor (* 100 (/ these-papers-count paper-count))))
                (list (sec-title s)
                      (string-append (number->string ratio) "%")
                      (make-string (if (> these-papers-count 0)
                                       (max ratio 1)
                                       0)
                                   #\•)))
              report-sections))
    (section "How to Review")
    review-protocol
    review-format
    (map (lambda (s)
           (make-section (sec-title s) (filter (sec-filter s) papers) (sec-left-col-color s) (sec-right-col-color s)))
         report-sections)
    (section "Threats to Validity")
    threats-to-validity
    )))

