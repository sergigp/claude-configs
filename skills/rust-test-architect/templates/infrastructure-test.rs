// Template for infrastructure tests using real services via testcontainers
// Place this file in the /tests directory of your crate

use chrono::{Duration, Utc};
use maplit::hashmap;
use pretty_assertions::assert_eq;
use test_context::test_context;
use test_utils::test_context::{StorageContext, PostgresStorageContext, KafkaContext};
use uuid::Uuid;

mod tests {

    #[test_context(StorageContext)]
    #[tokio::test(flavor = "multi_thread")]
    async fn test_usage_aggregation(ctx: &mut StorageContext) {
        // Arrange - Create unique test data
        let company_id = unique_company_id();
        let timestamp = Utc::now();
        let test_data = vec![
            (timestamp - Duration::hours(2), 100_000_000), // 100 MB
            (timestamp - Duration::hours(1), 150_000_000), // 150 MB
            (timestamp, 200_000_000),                      // 200 MB
        ];

        // Insert test data
        for (ts, size) in &test_data {
            insert_usage(&ctx.conn, company_id, *ts, *size).await
                .expect("Failed to insert test data");
        }

        // Act - Query aggregated data
        let result = ctx.conn
            .query_row::<u64>(
                &format!(
                    "SELECT SUM(size) FROM usage_1m WHERE company_id = {} AND timestamp >= '{}'",
                    company_id.0,
                    (timestamp - Duration::hours(3)).format("%Y-%m-%d %H:%M:%S")
                )
            )
            .await
            .expect("Query failed");

        // Assert
        assert_eq!(result, 450_000_000, "Sum should be 450 MB");
    }
}