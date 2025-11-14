# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_11_064953) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "brands", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_brands_on_name_unique", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "session_id", null: false
    t.string "status", default: "active"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_carts_on_created_at"
    t.index ["session_id"], name: "index_carts_on_session_id"
    t.index ["status", "created_at"], name: "index_carts_on_status_and_created_at"
    t.index ["status"], name: "index_carts_on_status"
    t.index ["user_id", "status"], name: "index_carts_on_user_id_and_status"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name_unique", unique: true
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "discount_id", null: false
    t.bigint "user_id"
    t.bigint "order_id"
    t.datetime "used_at"
    t.decimal "discount_amount", precision: 10, scale: 2
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["discount_id", "user_id"], name: "index_coupons_on_discount_id_and_user_id"
    t.index ["discount_id"], name: "index_coupons_on_discount_id"
    t.index ["order_id"], name: "index_coupons_on_order_id"
    t.index ["status"], name: "index_coupons_on_status"
    t.index ["used_at"], name: "index_coupons_on_used_at"
    t.index ["user_id"], name: "index_coupons_on_user_id"
  end

  create_table "discounts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "discount_type", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.decimal "minimum_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "maximum_discount", precision: 10, scale: 2
    t.integer "usage_limit"
    t.integer "used_count", default: 0
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean "is_active", default: true
    t.string "code", null: false
    t.json "conditions"
    t.string "applies_to", default: "all"
    t.text "applies_to_ids"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_discounts_on_code", unique: true
    t.index ["discount_type"], name: "index_discounts_on_discount_type"
    t.index ["is_active"], name: "index_discounts_on_is_active"
    t.index ["start_date", "end_date"], name: "index_discounts_on_start_date_and_end_date"
  end

  create_table "jwt_blacklist_tokens", force: :cascade do |t|
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.bigint "user_id"
    t.string "token_type", default: "access"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_jwt_blacklist_tokens_on_expires_at"
    t.index ["token"], name: "index_jwt_blacklist_tokens_on_token", unique: true
    t.index ["token_type"], name: "index_jwt_blacklist_tokens_on_token_type"
    t.index ["user_id"], name: "index_jwt_blacklist_tokens_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.boolean "read", default: false, null: false
    t.json "metadata"
    t.datetime "read_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read"], name: "index_notifications_on_read"
    t.index ["user_id", "notification_type"], name: "index_notifications_on_user_id_and_notification_type"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "customer_name"
    t.string "customer_email"
    t.string "customer_phone"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.string "tracking_number"
    t.string "carrier"
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.text "delivery_notes"
    t.string "delivery_signature"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.string "discount_code"
    t.bigint "discount_id"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["discount_code"], name: "index_orders_on_discount_code"
    t.index ["discount_id"], name: "index_orders_on_discount_id"
    t.index ["status", "created_at"], name: "index_orders_on_status_and_created_at"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.boolean "used", default: false
    t.string "ip_address"
    t.string "user_agent"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_password_reset_tokens_on_expires_at"
    t.index ["token"], name: "index_password_reset_tokens_on_token", unique: true
    t.index ["user_id", "used"], name: "index_password_reset_tokens_on_user_id_and_used"
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "payment_histories", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.string "action", null: false
    t.string "previous_status"
    t.string "new_status"
    t.decimal "amount", precision: 10, scale: 2
    t.string "transaction_id"
    t.text "gateway_response"
    t.string "performed_by"
    t.datetime "performed_at", null: false
    t.text "notes"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "performed_at"], name: "index_payment_histories_on_action_and_performed_at"
    t.index ["action"], name: "index_payment_histories_on_action"
    t.index ["new_status"], name: "index_payment_histories_on_new_status"
    t.index ["payment_id", "performed_at"], name: "index_payment_histories_on_payment_id_and_performed_at"
    t.index ["payment_id"], name: "index_payment_histories_on_payment_id"
    t.index ["performed_at"], name: "index_payment_histories_on_performed_at"
    t.index ["performed_by"], name: "index_payment_histories_on_performed_by"
    t.index ["previous_status"], name: "index_payment_histories_on_previous_status"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "gateway_type"
    t.json "gateway_config"
    t.decimal "processing_fee_percentage", precision: 5, scale: 2, default: "0.0"
    t.decimal "processing_fee_fixed", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gateway_type"], name: "index_payment_methods_on_gateway_type"
    t.index ["is_active"], name: "index_payment_methods_on_is_active"
    t.index ["name"], name: "index_payment_methods_on_name", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "payment_method_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "transaction_id"
    t.text "gateway_response"
    t.datetime "processed_at"
    t.string "failure_reason"
    t.json "metadata"
    t.string "currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payments_on_created_at"
    t.index ["order_id", "status"], name: "index_payments_on_order_id_and_status"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["payment_method_id"], name: "index_payments_on_payment_method_id"
    t.index ["processed_at"], name: "index_payments_on_processed_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["transaction_id"], name: "index_payments_on_transaction_id", unique: true
  end

  create_table "product_comparison_items", force: :cascade do |t|
    t.bigint "product_comparison_id", null: false
    t.bigint "product_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_product_comparison_items_on_position"
    t.index ["product_comparison_id", "product_id"], name: "index_pci_on_comparison_and_product", unique: true
    t.index ["product_comparison_id"], name: "index_product_comparison_items_on_product_comparison_id"
    t.index ["product_id"], name: "index_product_comparison_items_on_product_id"
  end

  create_table "product_comparisons", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "product_ids", null: false
    t.string "name", limit: 255
    t.json "comparison_data"
    t.boolean "is_public", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "index_product_comparisons_on_is_public"
    t.index ["user_id", "created_at"], name: "index_product_comparisons_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_product_comparisons_on_user_id"
  end

  create_table "product_reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "rating", null: false
    t.string "title", limit: 255
    t.text "content"
    t.integer "helpful_count", default: 0
    t.boolean "verified_purchase", default: false
    t.string "status", default: "pending"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_product_reviews_on_created_at"
    t.index ["product_id", "rating"], name: "index_product_reviews_on_product_id_and_rating"
    t.index ["product_id", "status"], name: "index_product_reviews_on_product_id_and_status"
    t.index ["product_id"], name: "index_product_reviews_on_product_id"
    t.index ["user_id", "product_id"], name: "index_product_reviews_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_product_reviews_on_user_id"
  end

  create_table "product_wishlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.text "notes"
    t.integer "priority", default: 0
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority"], name: "index_product_wishlists_on_priority"
    t.index ["product_id"], name: "index_product_wishlists_on_product_id"
    t.index ["user_id", "created_at"], name: "index_product_wishlists_on_user_id_and_created_at"
    t.index ["user_id", "product_id"], name: "index_product_wishlists_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_product_wishlists_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price", precision: 10, scale: 2
    t.bigint "brand_id", null: false
    t.bigint "category_id", null: false
    t.integer "stock_quantity"
    t.string "image_url"
    t.text "specifications"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["price", "stock_quantity"], name: "index_products_on_price_and_stock_quantity"
    t.index ["price"], name: "index_products_on_price"
    t.index ["stock_quantity"], name: "index_products_on_stock_quantity"
  end

  create_table "promotions", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "promotion_type", null: false
    t.json "conditions"
    t.json "benefits"
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean "is_active", default: true
    t.integer "usage_limit"
    t.integer "used_count", default: 0
    t.string "priority", default: "normal"
    t.boolean "stackable", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_promotions_on_is_active"
    t.index ["priority"], name: "index_promotions_on_priority"
    t.index ["promotion_type"], name: "index_promotions_on_promotion_type"
    t.index ["start_date", "end_date"], name: "index_promotions_on_start_date_and_end_date"
  end

  create_table "stock_alerts", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "alert_type", null: false
    t.integer "threshold", null: false
    t.integer "current_stock", null: false
    t.string "status", default: "active", null: false
    t.datetime "triggered_at", null: false
    t.datetime "resolved_at"
    t.boolean "notification_sent", default: false, null: false
    t.text "message"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type"], name: "index_stock_alerts_on_alert_type"
    t.index ["notification_sent"], name: "index_stock_alerts_on_notification_sent"
    t.index ["product_id", "alert_type", "status"], name: "index_stock_alerts_on_product_id_and_alert_type_and_status"
    t.index ["product_id"], name: "index_stock_alerts_on_product_id"
    t.index ["status", "notification_sent"], name: "index_stock_alerts_on_status_and_notification_sent"
    t.index ["status"], name: "index_stock_alerts_on_status"
    t.index ["triggered_at"], name: "index_stock_alerts_on_triggered_at"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "movement_type", null: false
    t.integer "quantity", null: false
    t.integer "previous_quantity", null: false
    t.integer "new_quantity", null: false
    t.string "reason"
    t.string "reference_type"
    t.integer "reference_id"
    t.json "metadata"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_stock_movements_on_created_at"
    t.index ["movement_type", "created_at"], name: "index_stock_movements_on_movement_type_and_created_at"
    t.index ["movement_type"], name: "index_stock_movements_on_movement_type"
    t.index ["product_id", "created_at"], name: "index_stock_movements_on_product_id_and_created_at"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["reference_type", "reference_id"], name: "index_stock_movements_on_reference_type_and_reference_id"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
  end

  create_table "user_addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address_type", default: "shipping"
    t.string "full_name", null: false
    t.string "phone"
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "state"
    t.string "postal_code", null: false
    t.string "country", default: "VN", null: false
    t.boolean "is_default", default: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_user_addresses_on_created_at"
    t.index ["user_id", "address_type"], name: "index_user_addresses_on_user_id_and_address_type"
    t.index ["user_id", "is_default"], name: "index_user_addresses_on_user_id_and_is_default"
    t.index ["user_id"], name: "index_user_addresses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_verified_at"
    t.string "email_verification_token"
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.date "date_of_birth"
    t.string "gender"
    t.string "avatar"
    t.text "bio"
    t.json "preferences", default: {}
    t.index ["date_of_birth"], name: "index_users_on_date_of_birth"
    t.index ["email"], name: "index_users_on_email_unique", unique: true
    t.index ["email_verification_token"], name: "index_users_on_email_verification_token", unique: true
    t.index ["phone"], name: "index_users_on_phone"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "coupons", "discounts"
  add_foreign_key "coupons", "orders"
  add_foreign_key "coupons", "users"
  add_foreign_key "jwt_blacklist_tokens", "users", on_delete: :nullify
  add_foreign_key "notifications", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "discounts"
  add_foreign_key "orders", "users"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "payment_histories", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "payment_methods"
  add_foreign_key "product_comparison_items", "product_comparisons", on_delete: :cascade
  add_foreign_key "product_comparison_items", "products", on_delete: :cascade
  add_foreign_key "product_comparisons", "users"
  add_foreign_key "product_reviews", "products"
  add_foreign_key "product_reviews", "users"
  add_foreign_key "product_wishlists", "products"
  add_foreign_key "product_wishlists", "users"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
  add_foreign_key "stock_alerts", "products"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "user_addresses", "users"
end
