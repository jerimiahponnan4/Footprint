(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_CREDITS (err u104))
(define-constant ERR_LISTING_NOT_ACTIVE (err u105))
(define-constant ERR_CANNOT_BUY_OWN_LISTING (err u106))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u107))
(define-constant ERR_EVIDENCE_NOT_FOUND (err u108))
(define-constant ERR_ALREADY_VERIFIED (err u109))
(define-constant ERR_CANNOT_VERIFY_OWN (err u110))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u111))

(define-data-var next-emission-id uint u1)
(define-data-var next-offset-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var next-evidence-id uint u1)

(define-map user-profiles
  { user: principal }
  {
    total-emissions: uint,
    total-offsets: uint,
    net-footprint: int,
    created-at: uint,
    available-credits: uint,
    verification-score: uint,
    total-verifications-given: uint
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

(define-map credit-listings
  { listing-id: uint }
  {
    seller: principal,
    credits-amount: uint,
    price-per-credit: uint,
    total-price: uint,
    is-active: bool,
    created-at: uint,
    expires-at: uint
  }
)

(define-map marketplace-transactions
  { transaction-id: uint }
  {
    listing-id: uint,
    buyer: principal,
    seller: principal,
    credits-amount: uint,
    total-price: uint,
    timestamp: uint
  }
)

(define-map user-marketplace-stats
  { user: principal }
  {
    total-sold: uint,
    total-bought: uint,
    total-earned: uint,
    total-spent: uint,
    transactions-count: uint
  }
)

(define-map evidence-submissions
  { evidence-id: uint }
  {
    submitter: principal,
    evidence-type: (string-ascii 20), ;; "emission" or "offset"
    related-id: uint, ;; emission-id or offset-id
    evidence-hash: (string-ascii 64), ;; SHA256 hash of evidence file
    description: (string-ascii 300),
    timestamp: uint,
    verification-count: uint,
    verified-as-valid: uint,
    verified-as-invalid: uint,
    is-verified: bool,
    verification-result: bool
  }
)

(define-map evidence-verifications
  { evidence-id: uint, verifier: principal }
  {
    is-valid: bool,
    timestamp: uint,
    verifier-reputation: uint
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
            created-at: stacks-block-height,
            available-credits: u0,
            verification-score: u100,
            total-verifications-given: u0
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
            created-at: (get created-at current-profile),
            available-credits: (get available-credits current-profile),
            verification-score: (get verification-score current-profile),
            total-verifications-given: (get total-verifications-given current-profile)
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
            created-at: (get created-at current-profile),
            available-credits: (+ (get available-credits current-profile) amount),
            verification-score: (get verification-score current-profile),
            total-verifications-given: (get total-verifications-given current-profile)
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

(define-public (list-credits-for-sale (credits-amount uint) (price-per-credit uint) (duration-blocks uint))
  (let (
    (user tx-sender)
    (listing-id (var-get next-listing-id))
    (user-profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND))
    (total-price (* credits-amount price-per-credit))
    (expires-at (+ stacks-block-height duration-blocks))
  )
    (asserts! (> credits-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-credit u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get available-credits user-profile) credits-amount) ERR_INSUFFICIENT_CREDITS)
    (map-set credit-listings
      { listing-id: listing-id }
      {
        seller: user,
        credits-amount: credits-amount,
        price-per-credit: price-per-credit,
        total-price: total-price,
        is-active: true,
        created-at: stacks-block-height,
        expires-at: expires-at
      }
    )
    (map-set user-profiles
      { user: user }
      {
        total-emissions: (get total-emissions user-profile),
        total-offsets: (get total-offsets user-profile),
        net-footprint: (get net-footprint user-profile),
        created-at: (get created-at user-profile),
        available-credits: (- (get available-credits user-profile) credits-amount),
        verification-score: (get verification-score user-profile),
        total-verifications-given: (get total-verifications-given user-profile)
      }
    )
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let (
    (user tx-sender)
    (listing (unwrap! (map-get? credit-listings { listing-id: listing-id }) ERR_NOT_FOUND))
    (user-profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get seller listing) user) ERR_UNAUTHORIZED)
    (asserts! (get is-active listing) ERR_LISTING_NOT_ACTIVE)
    (map-set credit-listings
      { listing-id: listing-id }
      {
        seller: (get seller listing),
        credits-amount: (get credits-amount listing),
        price-per-credit: (get price-per-credit listing),
        total-price: (get total-price listing),
        is-active: false,
        created-at: (get created-at listing),
        expires-at: (get expires-at listing)
      }
    )
    (map-set user-profiles
      { user: user }
      {
        total-emissions: (get total-emissions user-profile),
        total-offsets: (get total-offsets user-profile),
        net-footprint: (get net-footprint user-profile),
        created-at: (get created-at user-profile),
        available-credits: (+ (get available-credits user-profile) (get credits-amount listing)),
        verification-score: (get verification-score user-profile),
        total-verifications-given: (get total-verifications-given user-profile)
      }
    )
    (ok true)
  )
)

(define-public (buy-credits (listing-id uint) (credits-amount uint))
  (let (
    (buyer tx-sender)
    (listing (unwrap! (map-get? credit-listings { listing-id: listing-id }) ERR_NOT_FOUND))
    (seller (get seller listing))
    (buyer-profile (unwrap! (map-get? user-profiles { user: buyer }) ERR_NOT_FOUND))
    (seller-profile (unwrap! (map-get? user-profiles { user: seller }) ERR_NOT_FOUND))
    (transaction-id (var-get next-transaction-id))
    (cost (* credits-amount (get price-per-credit listing)))
    (remaining-credits (- (get credits-amount listing) credits-amount))
  )
    (asserts! (not (is-eq buyer seller)) ERR_CANNOT_BUY_OWN_LISTING)
    (asserts! (get is-active listing) ERR_LISTING_NOT_ACTIVE)
    (asserts! (< stacks-block-height (get expires-at listing)) ERR_LISTING_NOT_ACTIVE)
    (asserts! (> credits-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= credits-amount (get credits-amount listing)) ERR_INSUFFICIENT_CREDITS)
    (map-set marketplace-transactions
      { transaction-id: transaction-id }
      {
        listing-id: listing-id,
        buyer: buyer,
        seller: seller,
        credits-amount: credits-amount,
        total-price: cost,
        timestamp: stacks-block-height
      }
    )
    (map-set user-profiles
      { user: buyer }
      {
        total-emissions: (get total-emissions buyer-profile),
        total-offsets: (get total-offsets buyer-profile),
        net-footprint: (get net-footprint buyer-profile),
        created-at: (get created-at buyer-profile),
        available-credits: (+ (get available-credits buyer-profile) credits-amount),
        verification-score: (get verification-score buyer-profile),
        total-verifications-given: (get total-verifications-given buyer-profile)
      }
    )
    (let ((buyer-stats (default-to { total-sold: u0, total-bought: u0, total-earned: u0, total-spent: u0, transactions-count: u0 }
                                   (map-get? user-marketplace-stats { user: buyer }))))
      (map-set user-marketplace-stats
        { user: buyer }
        {
          total-sold: (get total-sold buyer-stats),
          total-bought: (+ (get total-bought buyer-stats) credits-amount),
          total-earned: (get total-earned buyer-stats),
          total-spent: (+ (get total-spent buyer-stats) cost),
          transactions-count: (+ (get transactions-count buyer-stats) u1)
        }
      )
    )
    (let ((seller-stats (default-to { total-sold: u0, total-bought: u0, total-earned: u0, total-spent: u0, transactions-count: u0 }
                                    (map-get? user-marketplace-stats { user: seller }))))
      (map-set user-marketplace-stats
        { user: seller }
        {
          total-sold: (+ (get total-sold seller-stats) credits-amount),
          total-bought: (get total-bought seller-stats),
          total-earned: (+ (get total-earned seller-stats) cost),
          total-spent: (get total-spent seller-stats),
          transactions-count: (+ (get transactions-count seller-stats) u1)
        }
      )
    )
    (if (is-eq remaining-credits u0)
      (map-set credit-listings
        { listing-id: listing-id }
        {
          seller: seller,
          credits-amount: u0,
          price-per-credit: (get price-per-credit listing),
          total-price: (get total-price listing),
          is-active: false,
          created-at: (get created-at listing),
          expires-at: (get expires-at listing)
        }
      )
      (map-set credit-listings
        { listing-id: listing-id }
        {
          seller: seller,
          credits-amount: remaining-credits,
          price-per-credit: (get price-per-credit listing),
          total-price: (* remaining-credits (get price-per-credit listing)),
          is-active: true,
          created-at: (get created-at listing),
          expires-at: (get expires-at listing)
        }
      )
    )
    (var-set next-transaction-id (+ transaction-id u1))
    (ok transaction-id)
  )
)

(define-public (update-listing-price (listing-id uint) (new-price-per-credit uint))
  (let (
    (user tx-sender)
    (listing (unwrap! (map-get? credit-listings { listing-id: listing-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get seller listing) user) ERR_UNAUTHORIZED)
    (asserts! (get is-active listing) ERR_LISTING_NOT_ACTIVE)
    (asserts! (> new-price-per-credit u0) ERR_INVALID_AMOUNT)
    (map-set credit-listings
      { listing-id: listing-id }
      {
        seller: (get seller listing),
        credits-amount: (get credits-amount listing),
        price-per-credit: new-price-per-credit,
        total-price: (* (get credits-amount listing) new-price-per-credit),
        is-active: (get is-active listing),
        created-at: (get created-at listing),
        expires-at: (get expires-at listing)
      }
    )
    (ok true)
  )
)

(define-read-only (get-listing (listing-id uint))
  (map-get? credit-listings { listing-id: listing-id })
)

(define-read-only (get-marketplace-transaction (transaction-id uint))
  (map-get? marketplace-transactions { transaction-id: transaction-id })
)

(define-read-only (get-user-marketplace-stats (user principal))
  (map-get? user-marketplace-stats { user: user })
)

(define-read-only (get-user-available-credits (user principal))
  (match (map-get? user-profiles { user: user })
    profile (some (get available-credits profile))
    none
  )
)

(define-read-only (get-active-listings-count)
  (var-get next-listing-id)
)

(define-read-only (get-total-marketplace-transactions)
  (var-get next-transaction-id)
)

(define-read-only (is-listing-expired (listing-id uint))
  (match (map-get? credit-listings { listing-id: listing-id })
    listing (>= stacks-block-height (get expires-at listing))
    false
  )
)

;; Evidence and Verification System
(define-public (submit-evidence (evidence-type (string-ascii 20)) (related-id uint) (evidence-hash (string-ascii 64)) (description (string-ascii 300)))
  (let (
    (user tx-sender)
    (evidence-id (var-get next-evidence-id))
    (user-profile (unwrap! (map-get? user-profiles { user: user }) ERR_NOT_FOUND))
  )
    ;; Validate evidence type
    (asserts! (or (is-eq evidence-type "emission") (is-eq evidence-type "offset")) ERR_INVALID_AMOUNT)
    ;; Validate related entry exists
    (if (is-eq evidence-type "emission")
      (asserts! (is-some (map-get? emissions { emission-id: related-id })) ERR_NOT_FOUND)
      (asserts! (is-some (map-get? offsets { offset-id: related-id })) ERR_NOT_FOUND)
    )
    ;; Create evidence submission
    (map-set evidence-submissions
      { evidence-id: evidence-id }
      {
        submitter: user,
        evidence-type: evidence-type,
        related-id: related-id,
        evidence-hash: evidence-hash,
        description: description,
        timestamp: stacks-block-height,
        verification-count: u0,
        verified-as-valid: u0,
        verified-as-invalid: u0,
        is-verified: false,
        verification-result: false
      }
    )
    (var-set next-evidence-id (+ evidence-id u1))
    (ok evidence-id)
  )
)

(define-public (verify-evidence (evidence-id uint) (is-valid bool))
  (let (
    (verifier tx-sender)
    (evidence (unwrap! (map-get? evidence-submissions { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND))
    (verifier-profile (unwrap! (map-get? user-profiles { user: verifier }) ERR_NOT_FOUND))
    (submitter-profile (unwrap! (map-get? user-profiles { user: (get submitter evidence) }) ERR_NOT_FOUND))
  )
    ;; Check if already verified by this user
    (asserts! (is-none (map-get? evidence-verifications { evidence-id: evidence-id, verifier: verifier })) ERR_ALREADY_VERIFIED)
    ;; Cannot verify own evidence
    (asserts! (not (is-eq verifier (get submitter evidence))) ERR_CANNOT_VERIFY_OWN)
    ;; Must have sufficient reputation (score >= 50)
    (asserts! (>= (get verification-score verifier-profile) u50) ERR_INSUFFICIENT_REPUTATION)
    
    ;; Record verification
    (map-set evidence-verifications
      { evidence-id: evidence-id, verifier: verifier }
      {
        is-valid: is-valid,
        timestamp: stacks-block-height,
        verifier-reputation: (get verification-score verifier-profile)
      }
    )
    
    ;; Update evidence counts
    (let (
      (new-verification-count (+ (get verification-count evidence) u1))
      (new-valid-count (if is-valid (+ (get verified-as-valid evidence) u1) (get verified-as-valid evidence)))
      (new-invalid-count (if is-valid (get verified-as-invalid evidence) (+ (get verified-as-invalid evidence) u1)))
    )
      (map-set evidence-submissions
        { evidence-id: evidence-id }
        {
          submitter: (get submitter evidence),
          evidence-type: (get evidence-type evidence),
          related-id: (get related-id evidence),
          evidence-hash: (get evidence-hash evidence),
          description: (get description evidence),
          timestamp: (get timestamp evidence),
          verification-count: new-verification-count,
          verified-as-valid: new-valid-count,
          verified-as-invalid: new-invalid-count,
          is-verified: (>= new-verification-count u3),
          verification-result: (if (>= new-verification-count u3) (> new-valid-count new-invalid-count) false)
        }
      )
    )
    
    ;; Update verifier stats - increase verifications given
    (map-set user-profiles
      { user: verifier }
      {
        total-emissions: (get total-emissions verifier-profile),
        total-offsets: (get total-offsets verifier-profile),
        net-footprint: (get net-footprint verifier-profile),
        created-at: (get created-at verifier-profile),
        available-credits: (get available-credits verifier-profile),
        verification-score: (get verification-score verifier-profile),
        total-verifications-given: (+ (get total-verifications-given verifier-profile) u1)
      }
    )
    
    ;; Update submitter reputation based on verification result
    (let ((updated-evidence (unwrap! (map-get? evidence-submissions { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND)))
      (if (and (get is-verified updated-evidence) (>= (get verification-count updated-evidence) u3))
        (let (
          (reputation-change (if (get verification-result updated-evidence) u5 (- u0 u10)))
          (new-score (if (get verification-result updated-evidence) 
                      (+ (get verification-score submitter-profile) u5)
                      (if (>= (get verification-score submitter-profile) u10)
                        (- (get verification-score submitter-profile) u10)
                        u0)))
        )
          (map-set user-profiles
            { user: (get submitter evidence) }
            {
              total-emissions: (get total-emissions submitter-profile),
              total-offsets: (get total-offsets submitter-profile),
              net-footprint: (get net-footprint submitter-profile),
              created-at: (get created-at submitter-profile),
              available-credits: (get available-credits submitter-profile),
              verification-score: new-score,
              total-verifications-given: (get total-verifications-given submitter-profile)
            }
          )
        )
        true
      )
    )
    (ok true)
  )
)

;; Read-only functions for verification system
(define-read-only (get-evidence (evidence-id uint))
  (map-get? evidence-submissions { evidence-id: evidence-id })
)

(define-read-only (get-evidence-verification (evidence-id uint) (verifier principal))
  (map-get? evidence-verifications { evidence-id: evidence-id, verifier: verifier })
)

(define-read-only (get-user-verification-score (user principal))
  (match (map-get? user-profiles { user: user })
    profile (some (get verification-score profile))
    none
  )
)

(define-read-only (get-user-verifications-given (user principal))
  (match (map-get? user-profiles { user: user })
    profile (some (get total-verifications-given profile))
    none
  )
)

(define-read-only (get-total-evidence-submissions)
  (var-get next-evidence-id)
)

(define-read-only (is-evidence-verified (evidence-id uint))
  (match (map-get? evidence-submissions { evidence-id: evidence-id })
    evidence (and (get is-verified evidence) (get verification-result evidence))
    false
  )
)


