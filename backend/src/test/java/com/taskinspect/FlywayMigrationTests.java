package com.taskinspect;

import static org.assertj.core.api.Assertions.assertThat;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
class FlywayMigrationTests {

    @Autowired
    private Flyway flyway;

    @Test
    void allMigrationsAreAppliedOnStartup() {
        MigrationInfo[] applied = flyway.info().applied();
        MigrationInfo[] pending = flyway.info().pending();

        assertThat(applied).isNotEmpty();
        assertThat(applied).allSatisfy(migration -> assertThat(migration.getState().isFailed()).isFalse());
        assertThat(pending).isEmpty();
        assertThat(applied[0].getVersion().getVersion()).isEqualTo("1");
    }

    @Test
    void migrationsAreValid() {
        assertThat(flyway.validateWithResult().validationSuccessful).isTrue();
    }

}
