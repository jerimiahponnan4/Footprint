(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))

(define-data-var next-emission-id uint u1)
(define-data-var next-offset-id uint u1)

(define-map user-profiles
  { user: principal }
  {
    total-emissions: uint,
    total-offsets: uint,
    net-footprint: int,
    created-at: uint
  }
)

(define-map emissions
  { emission-id: uint }
  {
    user: principal,
    category: (string-ascii 50),
    amount: uint,
    description: (string-ascii 200),
    timestamp: uint
  }
)

(define-map offsets
  { offset-id: uint }
  {
    user: principal,
    project: (string-ascii 100),
    amount: uint,
    price: uint,
    timestamp: uint
  }
)

(define-map category-totals
  { user: principal, category: (string-ascii 50) }
  { total: uint }
)

(define-map leaderboard
  { user: principal }
  {
    rank: uint,
    net-footprint: int,
    last-updated: uint
  }
)

(define-public (create-profile)
  (let ((user tx-sender))
    (if (is-some (map-get? user-profiles { user: user }))
      ERR_ALREADY_EXISTS
      (begin
        (map-set user-profiles
          { user: user }
          {
            total-emissions: u0,
            total-offsets: u0,
            net-footprint: 0,
            created-at: stacks-block-height
          }
        )
        (ok true)
      )
    )
  )
)

(define-public (add-emission (category (string-ascii 50)) (amount uint) (description (string-ascii 200)))
  (let (
    (user tx-sender)
    (emission-id (var-get next-emission-id))
    (current-profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND))
  )
    (if (is-eq amount u0)
      ERR_INVALID_AMOUNT
      (begin
        (map-set emissions
          { emission-id: emission-id }
          {
            user: user,
            category: category,
            amount: amount,
            description: description,
            timestamp: stacks-block-height
          }
        )
        (let ((current-category-total (default-to u0 (get total (map-get? category-totals { user: user, category: category })))))
          (map-set category-totals
            { user: user, category: category }
            { total: (+ current-category-total amount) }
          )
        )
        (map-set user-profiles
          { user: user }
          {
            total-emissions: (+ (get total-emissions current-profile) amount),
            total-offsets: (get total-offsets current-profile),
            net-footprint: (- (to-int (+ (get total-emissions current-profile) amount)) (to-int (get total-offsets current-profile))),
            created-at: (get created-at current-profile)
          }
        )
        (var-set next-emission-id (+ emission-id u1))
        (try! (update-leaderboard user))
        (ok emission-id)
      )
    )
  )
)

(define-public (add-offset (project (string-ascii 100)) (amount uint) (price uint))
  (let (
    (user tx-sender)
    (offset-id (var-get next-offset-id))
    (current-profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND))
  )
    (if (is-eq amount u0)
      ERR_INVALID_AMOUNT
      (begin
        (map-set offsets
          { offset-id: offset-id }
          {
            user: user,
            project: project,
            amount: amount,
            price: price,
            timestamp: stacks-block-height
          }
        )
        (map-set user-profiles
          { user: user }
          {
            total-emissions: (get total-emissions current-profile),
            total-offsets: (+ (get total-offsets current-profile) amount),
            net-footprint: (- (to-int (get total-emissions current-profile)) (to-int (+ (get total-offsets current-profile) amount))),
            created-at: (get created-at current-profile)
          }
        )
        (var-set next-offset-id (+ offset-id u1))
        (try! (update-leaderboard user))
        (ok offset-id)
      )
    )
  )
)

(define-private (update-leaderboard (user principal))
  (let ((profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND)))
    (map-set leaderboard
      { user: user }
      {
        rank: u0,
        net-footprint: (get net-footprint profile),
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (set-emission-target (target uint))
  (let ((user tx-sender))
    (if (is-some (map-get? user-profiles { user: user }))
      (begin
        (map-set category-totals
          { user: user, category: "target" }
          { total: target }
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (get-emission (emission-id uint))
  (map-get? emissions { emission-id: emission-id })
)

(define-read-only (get-offset (offset-id uint))
  (map-get? offsets { offset-id: offset-id })
)

(define-read-only (get-category-total (user principal) (category (string-ascii 50)))
  (map-get? category-totals { user: user, category: category })
)

(define-read-only (get-leaderboard-entry (user principal))
  (map-get? leaderboard { user: user })
)

(define-read-only (get-net-footprint (user principal))
  (match (map-get? user-profiles { user: user })
    profile (some (get net-footprint profile))
    none
  )
)

(define-read-only (is-carbon-neutral (user principal))
  (match (get-net-footprint user)
    footprint (<= footprint 0)
    false
  )
)

(define-read-only (get-emission-target (user principal))
  (match (map-get? category-totals { user: user, category: "target" })
    target-data (some (get total target-data))
    none
  )
)

(define-read-only (calculate-target-progress (user principal))
  (match (get-user-profile user)
    profile (match (get-emission-target user)
      target (if (> target u0)
        (some (/ (* (get total-emissions profile) u100) target))
        none
      )
      none
    )
    none
  )
)

(define-read-only (get-total-platform-emissions)
  (var-get next-emission-id)
)

(define-read-only (get-total-platform-offsets)
  (var-get next-offset-id)
)