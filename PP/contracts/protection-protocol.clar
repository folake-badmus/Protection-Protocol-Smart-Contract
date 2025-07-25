;; Protection Protocol Smart Contract
;; Implements coverage management, assessment processing, and contribution handling

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-COVERAGE-EXISTS (err u101))
(define-constant ERR-COVERAGE-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-CONTRIBUTION (err u103))
(define-constant ERR-COVERAGE-EXPIRED (err u104))
(define-constant ERR-INVALID-ASSESSMENT (err u105))
(define-constant ERR-ASSESSMENT-ALREADY-PROCESSED (err u106))
(define-constant ERR-INVALID-PRINCIPAL (err u110))
(define-constant ERR-INVALID-COVERAGE-ID (err u111))

;; Data structures
(define-map coverages
    { coverage-id: uint, holder: principal }
    {
        protection-amount: uint,
        contribution-amount: uint,
        start-block: uint,
        end-block: uint,
        is-enabled: bool
    }
)

(define-map assessments
    { assessment-id: uint, coverage-id: uint }
    {
        requested-amount: uint,
        details: (string-ascii 256),
        state: (string-ascii 20),
        completed: bool,
        coverage-id: uint
    }
)

;; Storage variables
(define-data-var next-coverage-id uint u1)
(define-data-var next-assessment-id uint u1)
(define-data-var protocol-admin principal tx-sender)
(define-data-var total-contributions uint u0)
(define-data-var total-assessments-paid uint u0)

;; Administrative functions
(define-public (set-protocol-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (is-eq new-admin (var-get protocol-admin))) ERR-INVALID-PRINCIPAL)
        (var-set protocol-admin new-admin)
        (ok true)
    )
)

;; Coverage management functions
(define-public (create-coverage (protection-amount uint) (contribution-amount uint) (duration uint))
    (let
        (
            (coverage-id (var-get next-coverage-id))
            (start-block block-height)
            (end-block (+ block-height duration))
        )
        (asserts! (> protection-amount u0) (err u107))
        (asserts! (> contribution-amount u0) (err u108))
        (asserts! (> duration u0) (err u109))
        
        (map-insert coverages
            { coverage-id: coverage-id, holder: tx-sender }
            {
                protection-amount: protection-amount,
                contribution-amount: contribution-amount,
                start-block: start-block,
                end-block: end-block,
                is-enabled: true
            }
        )
        
        (var-set next-coverage-id (+ coverage-id u1))
        (ok coverage-id)
    )
)

(define-public (pay-contribution (coverage-id uint))
    (let
        (
            (coverage (unwrap! (get-coverage coverage-id) ERR-COVERAGE-NOT-FOUND))
            (contribution-amount (get contribution-amount coverage))
        )
        (asserts! (unwrap! (is-coverage-enabled coverage-id) ERR-COVERAGE-NOT-FOUND) ERR-COVERAGE-EXPIRED)
        (try! (stx-transfer? contribution-amount tx-sender (var-get protocol-admin)))
        (var-set total-contributions (+ (var-get total-contributions) contribution-amount))
        (ok true)
    )
)

;; Assessment processing functions
(define-public (submit-assessment (coverage-id uint) (requested-amount uint) (details (string-ascii 256)))
    (let
        (
            (assessment-id (var-get next-assessment-id))
            (coverage (unwrap! (get-coverage coverage-id) ERR-COVERAGE-NOT-FOUND))
            (validated-details (if (> (len details) u0) details "No details provided"))
        )
        (asserts! (unwrap! (is-coverage-enabled coverage-id) ERR-COVERAGE-NOT-FOUND) ERR-COVERAGE-EXPIRED)
        (asserts! (<= requested-amount (get protection-amount coverage)) ERR-INVALID-ASSESSMENT)
        
        (map-insert assessments
            { assessment-id: assessment-id, coverage-id: coverage-id }
            {
                requested-amount: requested-amount,
                details: validated-details,
                state: "PENDING",
                completed: false,
                coverage-id: coverage-id
            }
        )
        
        (var-set next-assessment-id (+ assessment-id u1))
        (ok assessment-id)
    )
)

(define-public (process-assessment (assessment-id uint) (coverage-id uint) (approved bool))
    (let
        (
            (assessment (unwrap! (get-assessment assessment-id coverage-id) ERR-INVALID-ASSESSMENT))
            (coverage-holder (unwrap! (get-coverage-holder-by-id coverage-id) ERR-COVERAGE-NOT-FOUND))
            (validated-coverage-id (get coverage-id assessment))
        )
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq coverage-id validated-coverage-id) ERR-INVALID-COVERAGE-ID)
        (asserts! (not (get completed assessment)) ERR-ASSESSMENT-ALREADY-PROCESSED)
        
        (if approved
            (begin
                (try! (stx-transfer? (get requested-amount assessment) (var-get protocol-admin) coverage-holder))
                (var-set total-assessments-paid (+ (var-get total-assessments-paid) (get requested-amount assessment)))
                (map-set assessments
                    { assessment-id: assessment-id, coverage-id: validated-coverage-id }
                    (merge-assessment assessment { state: "APPROVED", completed: true })
                )
                (ok true)
            )
            (begin
                (map-set assessments
                    { assessment-id: assessment-id, coverage-id: validated-coverage-id }
                    (merge-assessment assessment { state: "REJECTED", completed: true })
                )
                (ok true)
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-coverage (coverage-id uint))
    (map-get? coverages { coverage-id: coverage-id, holder: tx-sender })
)

(define-read-only (get-assessment (assessment-id uint) (coverage-id uint))
    (map-get? assessments { assessment-id: assessment-id, coverage-id: coverage-id })
)

(define-read-only (get-coverage-holder (coverage-id uint))
    (let ((coverage-key { coverage-id: coverage-id, holder: tx-sender }))
        (match (map-get? coverages coverage-key)
            coverage (ok tx-sender)
            ERR-COVERAGE-NOT-FOUND
        )
    )
)

(define-read-only (get-coverage-holder-by-id (coverage-id uint))
    (let
        (
            (coverage-data (unwrap! (map-get? coverages { coverage-id: coverage-id, holder: tx-sender }) ERR-COVERAGE-NOT-FOUND))
        )
        (ok tx-sender)
    )
)

(define-read-only (is-coverage-enabled (coverage-id uint))
    (match (get-coverage coverage-id)
        coverage (ok (and
            (get is-enabled coverage)
            (<= block-height (get end-block coverage))
        ))
        ERR-COVERAGE-NOT-FOUND
    )
)

;; Helper functions
(define-private (merge-assessment (assessment-data {
        requested-amount: uint,
        details: (string-ascii 256),
        state: (string-ascii 20),
        completed: bool,
        coverage-id: uint
    }) 
    (updates {
        state: (string-ascii 20),
        completed: bool
    }))
    {
        requested-amount: (get requested-amount assessment-data),
        details: (get details assessment-data),
        state: (get state updates),
        completed: (get completed updates),
        coverage-id: (get coverage-id assessment-data)
    }
)