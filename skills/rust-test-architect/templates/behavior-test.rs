// Template for behavior tests that test business logic through public APIs
// with mocked data access layer

#[cfg(test)]
mod tests {

    #[tokio::test]
    async fn it_should_do_something_when_condition() {
        let company_id = unique_company_id();

        let entity_one = Entity::new(...);
        let entity_two = Entity::new(...);

        let repository = should_return_whatever(
            MockRepository::new(),
            company_id,
            vec![entity_one, entity_two]
        );

        let service = build_service(repository);
        

        let result = service.process(company_id).await;

        let expeted_result = Response::new(vec![
            entity_one.id,
            entity_two.id,
        ]);

        assert_eq!(result, expeted_result);
    }

    fn build_service(
        repository: impl RepositoryTrait + Send + Sync + 'static,
    ) -> ServiceImpl {
        // test helper to build the service under test
    }

    fn should_return_whatever(
        mut repository: MockRepository,
        company_id: CompanyId,
        entities: Vec<Entity>,
    ) -> MockRepository {
        // test helper to set up mock
        repository
            .expect_get_entities_for_company()
            .withf(move |cid| *cid == company_id)
            .returning(move |_| {
                let entities = entities.clone();
                Box::pin(async move { Ok(entities) })
            });
        repository
    }
}