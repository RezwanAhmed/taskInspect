package com.taskinspect.tasks;

/** Who may take an open task (docs/architecture.md, "Open Tasks"). Chosen by the manager per task. */
public enum OpenScope {

    /** Workers of the publishing manager's team. */
    TEAM,
    /** Every worker of the organization. */
    EVERYONE

}
