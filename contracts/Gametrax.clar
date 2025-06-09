(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-insufficient-payment (err u104))
(define-constant err-tournament-full (err u105))
(define-constant err-tournament-started (err u106))
(define-constant err-not-participant (err u107))
(define-constant err-invalid-winner (err u108))
(define-constant err-already-finalized (err u109))

(define-data-var tournament-counter uint u0)

(define-map tournaments uint {
    name: (string-ascii 50),
    entry-fee: uint,
    max-participants: uint,
    current-participants: uint,
    prize-pool: uint,
    status: (string-ascii 20),
    winner: (optional principal),
    creator: principal,
    created-at: uint
})

(define-map tournament-participants {tournament-id: uint, participant: principal} {
    joined-at: uint,
    paid: bool
})

(define-map participant-tournaments principal (list 100 uint))

(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id)
)

(define-read-only (get-tournament-participant (tournament-id uint) (participant principal))
    (map-get? tournament-participants {tournament-id: tournament-id, participant: participant})
)

(define-read-only (get-participant-tournaments (participant principal))
    (default-to (list) (map-get? participant-tournaments participant))
)

(define-read-only (get-tournament-counter)
    (var-get tournament-counter)
)

(define-public (create-tournament (name (string-ascii 50)) (entry-fee uint) (max-participants uint))
    (let (
        (tournament-id (+ (var-get tournament-counter) u1))
    )
        (asserts! (> max-participants u1) err-invalid-status)
        (asserts! (> entry-fee u0) err-invalid-status)
        (map-set tournaments tournament-id {
            name: name,
            entry-fee: entry-fee,
            max-participants: max-participants,
            current-participants: u0,
            prize-pool: u0,
            status: "open",
            winner: none,
            creator: tx-sender,
            created-at: stacks-block-height
        })
        (var-set tournament-counter tournament-id)
        (ok tournament-id)
    )
)

(define-public (join-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (entry-fee (get entry-fee tournament))
        (current-participants (get current-participants tournament))
        (max-participants (get max-participants tournament))
        (status (get status tournament))
        (existing-participant (get-tournament-participant tournament-id tx-sender))
    )
        (asserts! (is-eq status "open") err-tournament-started)
        (asserts! (is-none existing-participant) err-already-exists)
        (asserts! (< current-participants max-participants) err-tournament-full)
        (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
        (map-set tournament-participants 
            {tournament-id: tournament-id, participant: tx-sender}
            {joined-at: stacks-block-height, paid: true}
        )
        (map-set tournaments tournament-id (merge tournament {
            current-participants: (+ current-participants u1),
            prize-pool: (+ (get prize-pool tournament) entry-fee)
        }))
        (let (
            (current-tournaments (get-participant-tournaments tx-sender))
        )
            (map-set participant-tournaments tx-sender 
                (unwrap! (as-max-len? (append current-tournaments tournament-id) u100) err-tournament-full)
            )
        )
        (ok true)
    )
)

(define-public (start-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (creator (get creator tournament))
        (status (get status tournament))
        (current-participants (get current-participants tournament))
    )
        (asserts! (is-eq tx-sender creator) err-owner-only)
        (asserts! (is-eq status "open") err-invalid-status)
        (asserts! (>= current-participants u2) err-invalid-status)
        (map-set tournaments tournament-id (merge tournament {
            status: "active"
        }))
        (ok true)
    )
)

(define-public (declare-winner (tournament-id uint) (winner principal))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (creator (get creator tournament))
        (status (get status tournament))
        (prize-pool (get prize-pool tournament))
        (participant-info (get-tournament-participant tournament-id winner))
    )
        (asserts! (is-eq tx-sender creator) err-owner-only)
        (asserts! (is-eq status "active") err-invalid-status)
        (asserts! (is-some participant-info) err-invalid-winner)
        (map-set tournaments tournament-id (merge tournament {
            status: "completed",
            winner: (some winner)
        }))
        (as-contract (stx-transfer? prize-pool tx-sender winner))
    )
)

(define-public (cancel-tournament (tournament-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (creator (get creator tournament))
        (status (get status tournament))
    )
        (asserts! (is-eq tx-sender creator) err-owner-only)
        (asserts! (or (is-eq status "open") (is-eq status "active")) err-invalid-status)
        (map-set tournaments tournament-id (merge tournament {
            status: "cancelled"
        }))
        (ok true)
    )
)

(define-public (refund-participant (tournament-id uint) (participant principal))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (creator (get creator tournament))
        (status (get status tournament))
        (entry-fee (get entry-fee tournament))
        (participant-info (unwrap! (get-tournament-participant tournament-id participant) err-not-participant))
    )
        (asserts! (is-eq tx-sender creator) err-owner-only)
        (asserts! (is-eq status "cancelled") err-invalid-status)
        (asserts! (get paid participant-info) err-invalid-status)
        (map-set tournament-participants 
            {tournament-id: tournament-id, participant: participant}
            (merge participant-info {paid: false})
        )
        (as-contract (stx-transfer? entry-fee tx-sender participant))
    )
)

(define-read-only (get-tournament-status (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (ok (get status tournament))
        err-not-found
    )
)

(define-read-only (get-tournament-prize-pool (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (ok (get prize-pool tournament))
        err-not-found
    )
)

(define-read-only (is-tournament-participant (tournament-id uint) (participant principal))
    (is-some (get-tournament-participant tournament-id participant))
)

(define-read-only (get-tournament-winner (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (ok (get winner tournament))
        err-not-found
    )
)

(define-read-only (can-join-tournament (tournament-id uint))
    (match (get-tournament tournament-id)
        tournament (and 
            (is-eq (get status tournament) "open")
            (< (get current-participants tournament) (get max-participants tournament))
            (is-none (get-tournament-participant tournament-id tx-sender))
        )
        false
    )
)