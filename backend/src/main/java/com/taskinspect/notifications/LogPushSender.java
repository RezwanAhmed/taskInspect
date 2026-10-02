package com.taskinspect.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Push sender that sends nothing and only logs the notification
 * ({@code PUSH_TYPE=log}, the default until Firebase is set up). The token
 * is not logged.
 */
@Component
@ConditionalOnProperty(name = "taskinspect.push.type", havingValue = "log", matchIfMissing = true)
public class LogPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(LogPushSender.class);

    @Override
    public PushResult send(String token, PushMessage message) {
        log.info("Push notification (not sent, PUSH_TYPE=log): \"{}\" data={}", message.title(), message.data());
        return PushResult.SENT;
    }

}
