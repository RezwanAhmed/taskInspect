package com.taskinspect.requirements;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.requirements.dto.RequirementRequest;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.http.HttpStatus;

/** Unit tests of the type-dependent requirement settings (task 9.1a). */
class RequirementValidationTests {

    @ParameterizedTest
    @EnumSource(value = RequirementType.class, names = {"DROPDOWN", "MULTIPLE_SELECTION"})
    void choiceTypesNeedAtLeastTwoOptions(RequirementType type) {
        assertInvalid(request(type, null, null), type + " needs at least two options");
        assertInvalid(request(type, null, List.of()), type + " needs at least two options");
        assertInvalid(request(type, null, List.of("Only one")), type + " needs at least two options");
        assertThatCode(() -> RequirementService.validate(request(type, null, List.of("Yes", "No"))))
                .doesNotThrowAnyException();
    }

    @ParameterizedTest
    @EnumSource(value = RequirementType.class, names = {"DROPDOWN", "MULTIPLE_SELECTION"}, mode = EnumSource.Mode.EXCLUDE)
    void otherTypesHaveNoOptions(RequirementType type) {
        assertInvalid(request(type, null, List.of("A", "B")), type + " has no options");
        assertThatCode(() -> RequirementService.validate(request(type, null, null))).doesNotThrowAnyException();
        assertThatCode(() -> RequirementService.validate(request(type, null, List.of()))).doesNotThrowAnyException();
    }

    @Test
    void onlyNumberHasAUnit() {
        assertThatCode(() -> RequirementService.validate(request(RequirementType.NUMBER, "bar", null)))
                .doesNotThrowAnyException();
        assertInvalid(request(RequirementType.TEXT, "bar", null), "Only NUMBER requirements have a unit");
        assertInvalid(request(RequirementType.DROPDOWN, "bar", List.of("A", "B")),
                "Only NUMBER requirements have a unit");
    }

    @Test
    void aBlankUnitCountsAsNoUnit() {
        assertThatCode(() -> RequirementService.validate(request(RequirementType.TEXT, "  ", null)))
                .doesNotThrowAnyException();
    }

    private static RequirementRequest request(RequirementType type, String unit, List<String> options) {
        return new RequirementRequest("Check the pump", null, type, true, unit, options);
    }

    private static void assertInvalid(RequirementRequest request, String message) {
        assertThatThrownBy(() -> RequirementService.validate(request))
                .isInstanceOf(ApiException.class)
                .hasMessage(message)
                .extracting("status", "code")
                .containsExactly(HttpStatus.BAD_REQUEST, RequirementService.INVALID_REQUIREMENT);
    }

}
