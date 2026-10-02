package com.taskinspect.teams.dto;

import java.util.UUID;

/**
 * A manager's team in numbers only: what a worker may see of other teams
 * (docs/architecture.md, "What a Worker Sees").
 *
 * @param memberCount         active members of the team
 * @param unfinishedTaskCount tasks of the team members (also deactivated ones) that are not approved or
 *                            cancelled yet
 * @param myTeam              the caller leads this team or is a member of it
 */
public record TeamSummary(
        UUID managerId,
        String managerName,
        long memberCount,
        long unfinishedTaskCount,
        boolean myTeam) {
}
