package com.books.utils.opentelemetry;

import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility class for recording exceptions on OpenTelemetry spans.
 * This can be used across all services by including the utils dependency.
 */
public class OpenTelemetryExceptionResolver {
    
    private static final Logger logger = LoggerFactory.getLogger(OpenTelemetryExceptionResolver.class);
    
    /**
     * Record an exception on the current span
     * 
     * @param exception The exception to record
     */
    public static void recordException(Exception exception) {
        try {
            Span currentSpan = Span.current();
            
            // Only record if we have an active span
            if (currentSpan != null && currentSpan.getSpanContext().isValid()) {
                
                // Record the exception on the span
                currentSpan.recordException(exception);
                
                // Set span status to error
                currentSpan.setStatus(StatusCode.ERROR, exception.getMessage());
                
                // Add error event with detailed information
                currentSpan.addEvent("exception", 
                    Attributes.of(
                        AttributeKey.stringKey("error.type"), exception.getClass().getSimpleName(),
                        AttributeKey.stringKey("error.message"), exception.getMessage(),
                        AttributeKey.stringKey("error.source"), "ExceptionResolver"
                    ));
                
                logger.debug("Recorded exception {} on span: {}", 
                    exception.getClass().getSimpleName(), 
                    currentSpan.getSpanContext().getSpanId());
            }
        } catch (Exception e) {
            // Don't let span recording errors affect the application
            logger.warn("Failed to record exception on span: {}", e.getMessage());
        }
    }
    
    /**
     * Record an exception on the current span with custom message
     * 
     * @param exception The exception to record
     * @param message Custom error message
     */
    public static void recordException(Exception exception, String message) {
        try {
            Span currentSpan = Span.current();
            
            // Only record if we have an active span
            if (currentSpan != null && currentSpan.getSpanContext().isValid()) {
                
                // Record the exception on the span
                currentSpan.recordException(exception);
                
                // Set span status to error
                currentSpan.setStatus(StatusCode.ERROR, message);
                
                // Add error event with detailed information
                currentSpan.addEvent("exception", 
                    Attributes.of(
                        AttributeKey.stringKey("error.type"), exception.getClass().getSimpleName(),
                        AttributeKey.stringKey("error.message"), message,
                        AttributeKey.stringKey("error.source"), "ExceptionResolver"
                    ));
                
                logger.debug("Recorded exception {} on span: {}", 
                    exception.getClass().getSimpleName(), 
                    currentSpan.getSpanContext().getSpanId());
            }
        } catch (Exception e) {
            // Don't let span recording errors affect the application
            logger.warn("Failed to record exception on span: {}", e.getMessage());
        }
    }
} 