package com.books.utils.opentelemetry;

import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility class for recording HTTP errors on OpenTelemetry spans.
 * This addresses the issue where ResponseFacade.sendError doesn't attach error information to spans.
 * 
 * This utility can be used across all services by including the utils dependency.
 */
public class OpenTelemetryErrorFilter {
    
    private static final Logger logger = LoggerFactory.getLogger(OpenTelemetryErrorFilter.class);
    
    /**
     * Record an HTTP error on the current span
     * 
     * @param statusCode HTTP status code
     * @param message Error message (optional)
     */
    public static void recordHttpError(int statusCode, String message) {
        try {
            Span currentSpan = Span.current();
            
            // Only record if we have an active span
            if (currentSpan != null && currentSpan.getSpanContext().isValid()) {
                
                // Set span status to error
                currentSpan.setStatus(StatusCode.ERROR, 
                    message != null ? message : "HTTP Error " + statusCode);
                
                // Add error event with detailed information
                currentSpan.addEvent("http.error", 
                    Attributes.of(
                        AttributeKey.stringKey("http.status_code"), String.valueOf(statusCode),
                        AttributeKey.stringKey("http.error_message"), 
                            message != null ? message : "HTTP Error " + statusCode,
                        AttributeKey.stringKey("error.type"), "HTTP_ERROR",
                        AttributeKey.stringKey("error.source"), "ResponseFacade.sendError"
                    ));
                
                // Add additional context based on status code
                if (statusCode >= 400 && statusCode < 500) {
                    currentSpan.addEvent("http.client_error", 
                        Attributes.of(
                            AttributeKey.stringKey("http.status_code"), String.valueOf(statusCode),
                            AttributeKey.stringKey("error.category"), "CLIENT_ERROR"
                        ));
                } else if (statusCode >= 500) {
                    currentSpan.addEvent("http.server_error", 
                        Attributes.of(
                            AttributeKey.stringKey("http.status_code"), String.valueOf(statusCode),
                            AttributeKey.stringKey("error.category"), "SERVER_ERROR"
                        ));
                }
                
                logger.debug("Recorded HTTP error {} on span: {}", statusCode, currentSpan.getSpanContext().getSpanId());
            }
        } catch (Exception e) {
            // Don't let span recording errors affect the application
            logger.warn("Failed to record error on span: {}", e.getMessage());
        }
    }
    
    /**
     * Record an HTTP error on the current span (without message)
     * 
     * @param statusCode HTTP status code
     */
    public static void recordHttpError(int statusCode) {
        recordHttpError(statusCode, null);
    }
} 