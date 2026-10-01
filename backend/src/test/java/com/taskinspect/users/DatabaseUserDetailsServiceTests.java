package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

@DataJpaTest
@Import({TestcontainersConfiguration.class, DatabaseUserDetailsService.class})
class DatabaseUserDetailsServiceTests {

    @Autowired
    private DatabaseUserDetailsService service;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User user;

    @BeforeEach
    void setUp() {
        user = userRepository.save(new User(organizationRepository.getDefault(), "solo@example.com", "hash",
                "Solo", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow(),
                        roleRepository.findByName(RoleName.WORKER).orElseThrow())));
    }

    @Test
    void loadsUserByEmailIgnoringCaseWithRoleAuthorities() {
        UserDetails details = service.loadUserByUsername("SOLO@example.com");

        assertThat(details.getUsername()).isEqualTo("solo@example.com");
        assertThat(details.getPassword()).isEqualTo("hash");
        assertThat(details.isEnabled()).isTrue();
        assertThat(details.getAuthorities()).extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_MANAGER", "ROLE_WORKER");
    }

    @Test
    void deactivatedUserIsDisabled() {
        user.deactivate();

        assertThat(service.loadUserByUsername("solo@example.com").isEnabled()).isFalse();
    }

    @Test
    void unknownEmailThrows() {
        assertThatThrownBy(() -> service.loadUserByUsername("nobody@example.com"))
                .isInstanceOf(UsernameNotFoundException.class);
    }

}
