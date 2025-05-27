;; Accounting Protocol Contract
;; Records natural capital changes and maintains ledger

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_ENTRY (err u401))
(define-constant ERR_ASSET_NOT_FOUND (err u402))

;; Transaction types
(define-constant TX_INITIAL_RECORDING u1)
(define-constant TX_VALUE_INCREASE u2)
(define-constant TX_VALUE_DECREASE u3)
(define-constant TX_ASSET_TRANSFER u4)
(define-constant TX_SERVICE_UPDATE u5)

;; Accounting entries
(define-map accounting-entries
  uint
  {
    asset-id: uint,
    transaction-type: uint,
    service-type: (optional uint),
    previous-value: uint,
    new-value: uint,
    change-amount: uint,
    currency: (string-ascii 10),
    description: (string-ascii 200),
    recorded-by: principal,
    recorded-at: uint,
    reference-tx: (optional uint)
  }
)

;; Asset balances (current total value per asset)
(define-map asset-balances
  uint
  {
    total-value: uint,
    currency: (string-ascii 10),
    last-updated: uint,
    updated-by: principal
  }
)

;; Service balances (current value per service type per asset)
(define-map service-balances
  { asset-id: uint, service-type: uint }
  {
    current-value: uint,
    currency: (string-ascii 10),
    last-updated: uint,
    updated-by: principal
  }
)

;; Entry counter
(define-data-var next-entry-id uint u1)

;; Authorized accountants
(define-map authorized-accountants principal bool)

;; Record accounting entry
(define-public (record-entry
  (asset-id uint)
  (transaction-type uint)
  (service-type (optional uint))
  (new-value uint)
  (currency (string-ascii 10))
  (description (string-ascii 200)))
  (let (
    (entry-id (var-get next-entry-id))
    (current-balance (default-to u0 (get total-value (map-get? asset-balances asset-id))))
    (change-amount (if (> new-value current-balance)
                     (- new-value current-balance)
                     (- current-balance new-value)))
  )
    (asserts! (default-to false (map-get? authorized-accountants tx-sender)) ERR_UNAUTHORIZED)

    ;; Record the accounting entry
    (map-set accounting-entries
      entry-id
      {
        asset-id: asset-id,
        transaction-type: transaction-type,
        service-type: service-type,
        previous-value: current-balance,
        new-value: new-value,
        change-amount: change-amount,
        currency: currency,
        description: description,
        recorded-by: tx-sender,
        recorded-at: block-height,
        reference-tx: none
      }
    )

    ;; Update asset balance
    (map-set asset-balances
      asset-id
      {
        total-value: new-value,
        currency: currency,
        last-updated: block-height,
        updated-by: tx-sender
      }
    )

    ;; Update service balance if service-type is provided
    (match service-type
      service-id (map-set service-balances
                   { asset-id: asset-id, service-type: service-id }
                   {
                     current-value: new-value,
                     currency: currency,
                     last-updated: block-height,
                     updated-by: tx-sender
                   })
      true
    )

    (var-set next-entry-id (+ entry-id u1))
    (ok entry-id)
  )
)

;; Add authorized accountant (only contract owner)
(define-public (add-accountant (accountant principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-accountants accountant true)
    (ok true)
  )
)

;; Get accounting entry
(define-read-only (get-entry (entry-id uint))
  (map-get? accounting-entries entry-id)
)

;; Get asset balance
(define-read-only (get-asset-balance (asset-id uint))
  (map-get? asset-balances asset-id)
)

;; Get service balance
(define-read-only (get-service-balance (asset-id uint) (service-type uint))
  (map-get? service-balances { asset-id: asset-id, service-type: service-type })
)

;; Check if accountant is authorized
(define-read-only (is-authorized-accountant (accountant principal))
  (default-to false (map-get? authorized-accountants accountant))
)
