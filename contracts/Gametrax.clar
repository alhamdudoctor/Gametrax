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
(define-constant err-achievement-not-found (err u110))
(define-constant err-achievement-already-earned (err u111))
(define-constant err-invalid-achievement-type (err u112))
(define-constant err-insufficient-achievements (err u113))
(define-constant err-sponsor-not-found (err u114))
(define-constant err-invalid-sponsor-tier (err u115))
(define-constant err-insufficient-sponsorship (err u116))
(define-constant err-sponsorship-exists (err u117))
(define-constant err-invalid-revenue-share (err u118))

(define-data-var tournament-counter uint u0)
(define-data-var achievement-counter uint u0)
(define-data-var sponsor-counter uint u0)

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

(define-map achievements uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    achievement-type: (string-ascii 20),
    criteria-value: uint,
    nft-token-id: uint,
    created-at: uint
})

(define-map player-stats principal {
    tournaments-joined: uint,
    tournaments-won: uint,
    tournaments-completed: uint,
    total-prize-won: uint,
    win-streak: uint,
    max-win-streak: uint,
    achievements-earned: uint
})

(define-map player-achievements {player: principal, achievement-id: uint} {
    earned-at: uint,
    tournament-id: (optional uint)
})

(define-map player-achievement-list principal (list 50 uint))

(define-map achievement-leaderboard (string-ascii 20) (list 10 {player: principal, value: uint}))

(define-map achievement-nft-metadata uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    image: (string-ascii 200),
    rarity: (string-ascii 20)
})

;; Sponsorship system data maps
(define-map sponsors uint {
    name: (string-ascii 50),
    company: (string-ascii 100),
    contact-info: (string-ascii 200),
    sponsor-tier: (string-ascii 20),
    total-contributed: uint,
    tournaments-sponsored: uint,
    revenue-share-percentage: uint,
    active: bool,
    created-at: uint
})

(define-map tournament-sponsorships {tournament-id: uint, sponsor-id: uint} {
    contribution-amount: uint,
    revenue-share-earned: uint,
    sponsored-at: uint,
    benefits-claimed: bool
})

(define-map sponsor-tournament-list uint (list 50 uint))

(define-map sponsor-tier-benefits (string-ascii 20) {
    min-contribution: uint,
    revenue-share-percentage: uint,
    max-tournaments-per-month: uint,
    priority-placement: bool
})

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

(define-read-only (get-achievement (achievement-id uint))
    (map-get? achievements achievement-id)
)

(define-read-only (get-player-stats (player principal))
    (default-to {
        tournaments-joined: u0,
        tournaments-won: u0,
        tournaments-completed: u0,
        total-prize-won: u0,
        win-streak: u0,
        max-win-streak: u0,
        achievements-earned: u0
    } (map-get? player-stats player))
)

(define-read-only (get-player-achievement (player principal) (achievement-id uint))
    (map-get? player-achievements {player: player, achievement-id: achievement-id})
)

(define-read-only (get-player-achievements (player principal))
    (default-to (list) (map-get? player-achievement-list player))
)

(define-read-only (get-achievement-leaderboard (category (string-ascii 20)))
    (default-to (list) (map-get? achievement-leaderboard category))
)

(define-read-only (get-achievement-nft-metadata (token-id uint))
    (map-get? achievement-nft-metadata token-id)
)

;; Sponsorship read-only functions
(define-read-only (get-sponsor (sponsor-id uint))
    (map-get? sponsors sponsor-id)
)

(define-read-only (get-tournament-sponsorship (tournament-id uint) (sponsor-id uint))
    (map-get? tournament-sponsorships {tournament-id: tournament-id, sponsor-id: sponsor-id})
)

(define-read-only (get-sponsor-tournaments (sponsor-id uint))
    (default-to (list) (map-get? sponsor-tournament-list sponsor-id))
)

(define-read-only (get-sponsor-tier-benefits (tier (string-ascii 20)))
    (map-get? sponsor-tier-benefits tier)
)

(define-read-only (get-sponsor-counter)
    (var-get sponsor-counter)
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
            (current-stats (get-player-stats tx-sender))
        )
            (map-set participant-tournaments tx-sender 
                (unwrap! (as-max-len? (append current-tournaments tournament-id) u100) err-tournament-full)
            )
            (map-set player-stats tx-sender (merge current-stats {
                tournaments-joined: (+ (get tournaments-joined current-stats) u1)
            }))
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
        (try! (as-contract (stx-transfer? prize-pool tx-sender winner)))

        (ok true)
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

(define-public (create-achievement (name (string-ascii 50)) (description (string-ascii 200)) (achievement-type (string-ascii 20)) (criteria-value uint))
    (let (
        (achievement-id (+ (var-get achievement-counter) u1))
        (nft-token-id (+ (var-get achievement-counter) u1))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (or (is-eq achievement-type "wins") (is-eq achievement-type "participation") (is-eq achievement-type "streak")) err-invalid-achievement-type)
        (map-set achievements achievement-id {
            name: name,
            description: description,
            achievement-type: achievement-type,
            criteria-value: criteria-value,
            nft-token-id: nft-token-id,
            created-at: stacks-block-height
        })
        (map-set achievement-nft-metadata nft-token-id {
            name: name,
            description: description,
            image: "https://gametrax.com/achievements/default.png",
            rarity: "common"
        })
        (var-set achievement-counter achievement-id)
        (ok achievement-id)
    )
)

(define-private (update-player-stats-on-win (winner principal) (prize-amount uint) (tournament-id uint))
    (let (
        (current-stats (get-player-stats winner))
        (new-win-streak (+ (get win-streak current-stats) u1))
        (new-max-streak (if (> new-win-streak (get max-win-streak current-stats)) new-win-streak (get max-win-streak current-stats)))
        (new-stats (merge current-stats {
            tournaments-won: (+ (get tournaments-won current-stats) u1),
            total-prize-won: (+ (get total-prize-won current-stats) prize-amount),
            win-streak: new-win-streak,
            max-win-streak: new-max-streak
        }))
    )
        (map-set player-stats winner new-stats)
        (ok true)
    )
)

(define-public (award-achievement-manually (player principal) (achievement-id uint))
    (let (
        (achievement (unwrap! (get-achievement achievement-id) err-achievement-not-found))
        (current-achievements (get-player-achievements player))
        (current-stats (get-player-stats player))
        (already-earned (is-some (get-player-achievement player achievement-id)))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not already-earned) err-achievement-already-earned)
        (map-set player-achievements {player: player, achievement-id: achievement-id} {
            earned-at: stacks-block-height,
            tournament-id: none
        })
        (map-set player-achievement-list player 
            (unwrap! (as-max-len? (append current-achievements achievement-id) u50) err-insufficient-achievements)
        )
        (map-set player-stats player (merge current-stats {
            achievements-earned: (+ (get achievements-earned current-stats) u1)
        }))
        (ok true)
    )
)

(define-public (update-player-leaderboard (player principal) (category (string-ascii 20)) (value uint))
    (let (
        (current-board (get-achievement-leaderboard category))
        (new-entry {player: player, value: value})
        (updated-board (append current-board new-entry))
        (trimmed-board (default-to (list) (slice? updated-board u0 u10)))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (or (is-eq category "wins") (or (is-eq category "streak") (is-eq category "prize"))) err-invalid-achievement-type)
        (map-set achievement-leaderboard category (default-to (list) (as-max-len? trimmed-board u10)))
        (ok true)
    )
)

(define-public (check-achievement-eligibility (player principal) (achievement-id uint))
    (let (
        (achievement (unwrap! (get-achievement achievement-id) err-achievement-not-found))
        (current-player-stats (get-player-stats player))
        (achievement-type (get achievement-type achievement))
        (criteria-value (get criteria-value achievement))
        (player-value (if (is-eq achievement-type "wins") (get tournaments-won current-player-stats)
                        (if (is-eq achievement-type "participation") (get tournaments-joined current-player-stats)
                            (get max-win-streak current-player-stats))))
        (already-earned (is-some (get-player-achievement player achievement-id)))
    )
        (ok {
            eligible: (and (>= player-value criteria-value) (not already-earned)),
            current-value: player-value,
            required-value: criteria-value,
            already-earned: already-earned
        })
    )
)

(define-read-only (get-achievement-counter)
    (var-get achievement-counter)
)

(define-read-only (has-achievement (player principal) (achievement-id uint))
    (is-some (get-player-achievement player achievement-id))
)

(define-read-only (get-player-rank (player principal) (category (string-ascii 20)))
    (let (
        (board (get-achievement-leaderboard category))
        (current-player-stats (get-player-stats player))
        (player-value (if (is-eq category "wins") (get tournaments-won current-player-stats)
                        (if (is-eq category "streak") (get max-win-streak current-player-stats)
                            (get total-prize-won current-player-stats))))
        (higher-count (fold count-higher-values board {target: player-value, count: u0}))
    )
        (+ (get count higher-count) u1)
    )
)

(define-private (count-higher-values (entry {player: principal, value: uint}) (context {target: uint, count: uint}))
    (if (> (get value entry) (get target context))
        {target: (get target context), count: (+ (get count context) u1)}
        context
    )
)

(define-read-only (get-achievement-progress (player principal) (achievement-id uint))
    (let (
        (achievement (get-achievement achievement-id))
        (current-player-stats (get-player-stats player))
    )
        (match achievement
            achievement-data
            (let (
                (achievement-type (get achievement-type achievement-data))
                (criteria-value (get criteria-value achievement-data))
                (player-value (if (is-eq achievement-type "wins") (get tournaments-won current-player-stats)
                                (if (is-eq achievement-type "participation") (get tournaments-joined current-player-stats)
                                    (get max-win-streak current-player-stats))))
                (progress (if (>= player-value criteria-value) u100 
                            (/ (* player-value u100) criteria-value)))
            )
                (ok {current: player-value, required: criteria-value, progress: progress})
            )
            err-achievement-not-found
        )
    )
)

;; Sponsorship system functions
(define-public (create-sponsor-tier (tier (string-ascii 20)) (min-contribution uint) (revenue-share uint) (max-tournaments uint) (priority bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= revenue-share u100) err-invalid-revenue-share)
        (map-set sponsor-tier-benefits tier {
            min-contribution: min-contribution,
            revenue-share-percentage: revenue-share,
            max-tournaments-per-month: max-tournaments,
            priority-placement: priority
        })
        (ok true)
    )
)

(define-public (register-sponsor (name (string-ascii 50)) (company (string-ascii 100)) (contact-info (string-ascii 200)) (tier (string-ascii 20)))
    (let (
        (sponsor-id (+ (var-get sponsor-counter) u1))
        (tier-benefits (unwrap! (get-sponsor-tier-benefits tier) err-invalid-sponsor-tier))
        (revenue-share (get revenue-share-percentage tier-benefits))
    )
        (map-set sponsors sponsor-id {
            name: name,
            company: company,
            contact-info: contact-info,
            sponsor-tier: tier,
            total-contributed: u0,
            tournaments-sponsored: u0,
            revenue-share-percentage: revenue-share,
            active: true,
            created-at: stacks-block-height
        })
        (var-set sponsor-counter sponsor-id)
        (ok sponsor-id)
    )
)

(define-public (sponsor-tournament (tournament-id uint) (sponsor-id uint) (contribution-amount uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (sponsor (unwrap! (get-sponsor sponsor-id) err-sponsor-not-found))
        (tier-benefits (unwrap! (get-sponsor-tier-benefits (get sponsor-tier sponsor)) err-invalid-sponsor-tier))
        (existing-sponsorship (get-tournament-sponsorship tournament-id sponsor-id))
        (min-contribution (get min-contribution tier-benefits))
        (current-tournaments (get-sponsor-tournaments sponsor-id))
    )
        ;; Validate sponsor is active and contribution meets minimum
        (asserts! (get active sponsor) err-sponsor-not-found)
        (asserts! (>= contribution-amount min-contribution) err-insufficient-sponsorship)
        (asserts! (is-none existing-sponsorship) err-sponsorship-exists)
        (asserts! (or (is-eq (get status tournament) "open") (is-eq (get status tournament) "active")) err-tournament-started)
        
        ;; Transfer sponsorship funds to contract
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        ;; Update tournament prize pool
        (map-set tournaments tournament-id (merge tournament {
            prize-pool: (+ (get prize-pool tournament) contribution-amount)
        }))
        
        ;; Record sponsorship
        (map-set tournament-sponsorships {tournament-id: tournament-id, sponsor-id: sponsor-id} {
            contribution-amount: contribution-amount,
            revenue-share-earned: u0,
            sponsored-at: stacks-block-height,
            benefits-claimed: false
        })
        
        ;; Update sponsor stats
        (map-set sponsors sponsor-id (merge sponsor {
            total-contributed: (+ (get total-contributed sponsor) contribution-amount),
            tournaments-sponsored: (+ (get tournaments-sponsored sponsor) u1)
        }))
        
        ;; Add tournament to sponsor's list
        (map-set sponsor-tournament-list sponsor-id 
            (unwrap! (as-max-len? (append current-tournaments tournament-id) u50) err-tournament-full)
        )
        
        (ok true)
    )
)

(define-public (distribute-sponsor-revenue (tournament-id uint) (sponsor-id uint))
    (let (
        (tournament (unwrap! (get-tournament tournament-id) err-not-found))
        (sponsor (unwrap! (get-sponsor sponsor-id) err-sponsor-not-found))
        (sponsorship (unwrap! (get-tournament-sponsorship tournament-id sponsor-id) err-sponsor-not-found))
        (prize-pool (get prize-pool tournament))
        (contribution (get contribution-amount sponsorship))
        (revenue-share-percentage (get revenue-share-percentage sponsor))
        (revenue-earned (/ (* prize-pool revenue-share-percentage) u100))
    )
        ;; Only distribute revenue after tournament completion
        (asserts! (is-eq (get status tournament) "completed") err-invalid-status)
        (asserts! (not (get benefits-claimed sponsorship)) err-already-finalized)
        
        ;; Transfer revenue share to sponsor
        (try! (as-contract (stx-transfer? revenue-earned tx-sender tx-sender)))
        
        ;; Update sponsorship record
        (map-set tournament-sponsorships {tournament-id: tournament-id, sponsor-id: sponsor-id} 
            (merge sponsorship {
                revenue-share-earned: revenue-earned,
                benefits-claimed: true
            })
        )
        
        (ok revenue-earned)
    )
)

(define-public (update-sponsor-tier (sponsor-id uint) (new-tier (string-ascii 20)))
    (let (
        (sponsor (unwrap! (get-sponsor sponsor-id) err-sponsor-not-found))
        (tier-benefits (unwrap! (get-sponsor-tier-benefits new-tier) err-invalid-sponsor-tier))
        (new-revenue-share (get revenue-share-percentage tier-benefits))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set sponsors sponsor-id (merge sponsor {
            sponsor-tier: new-tier,
            revenue-share-percentage: new-revenue-share
        }))
        (ok true)
    )
)

(define-public (deactivate-sponsor (sponsor-id uint))
    (let (
        (sponsor (unwrap! (get-sponsor sponsor-id) err-sponsor-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set sponsors sponsor-id (merge sponsor {
            active: false
        }))
        (ok true)
    )
)

;; Read-only functions for sponsor analytics
(define-read-only (get-tournament-total-sponsorship (tournament-id uint))
    (let (
        (tournament (get-tournament tournament-id))
    )
        (match tournament
            tournament-data (ok (get prize-pool tournament-data))
            err-not-found
        )
    )
)

(define-read-only (get-sponsor-revenue-earned (sponsor-id uint))
    (let (
        (sponsor (get-sponsor sponsor-id))
        (sponsor-tournaments (get-sponsor-tournaments sponsor-id))
    )
        (match sponsor
            sponsor-data (ok {
                total-contributed: (get total-contributed sponsor-data),
                tournaments-sponsored: (get tournaments-sponsored sponsor-data),
                active: (get active sponsor-data)
            })
            err-sponsor-not-found
        )
    )
)

(define-read-only (calculate-potential-revenue (tournament-id uint) (sponsor-id uint))
    (let (
        (tournament (get-tournament tournament-id))
        (sponsor (get-sponsor sponsor-id))
    )
        (match tournament
            tournament-data
            (match sponsor
                sponsor-data
                (let (
                    (prize-pool (get prize-pool tournament-data))
                    (revenue-share (get revenue-share-percentage sponsor-data))
                    (potential-revenue (/ (* prize-pool revenue-share) u100))
                )
                    (ok potential-revenue)
                )
                err-sponsor-not-found
            )
            err-not-found
        )
    )
)

(define-read-only (get-active-sponsors)
    (ok (var-get sponsor-counter))
)



