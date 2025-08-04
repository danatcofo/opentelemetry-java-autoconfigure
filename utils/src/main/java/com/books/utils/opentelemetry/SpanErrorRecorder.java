package com.books.utils.opentelemetry;

import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility class for recording errors on OpenTelemetry spans.
 * Provides helper methods that can be used throughout the application.
 */
public class SpanErrorRecorder {
    
    private static final Logger logger = LoggerFactory.getLogger(SpanErrorRecorder.class);
    
    /**
     * Record an HTTP error on the current span
     * 
     * @param statusCode HTTP status code
     * @param message Error message
     */
    public static void recordHttpError(int statusCode, String message) {
        try {
            Span currentSpan = Span.current();
            
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
            logger.warn("Failed to record HTTP error on span: {}", e.getMessage());
        }
    }
    
    /**
     * Record an exception on the current span
     * 
     * @param exception The exception to record
     * @param context Additional context information
     */
    public static void recordException(Exception exception, String context) {
        try {
            Span currentSpan = Span.current();
            
            if (currentSpan != null && currentSpan.getSpanContext().isValid()) {
                // Record the exception on the span
                currentSpan.recordException(exception);
                currentSpan.setStatus(StatusCode.ERROR, 
                    context != null ? context + ": " + exception.getMessage() : exception.getMessage());
                
                // Add detailed error information
                currentSpan.addEvent("application.exception", 
                    Attributes.of(
                        AttributeKey.stringKey("error.type"), exception.getClass().getSimpleName(),
                        AttributeKey.stringKey("error.message"), exception.getMessage(),
                        AttributeKey.stringKey("error.context"), context != null ? context : "Unknown",
                        AttributeKey.stringKey("error.source"), "ApplicationException"
                    ));
                
                logger.debug("Recorded exception on span: {} - Exception: {}", 
                    currentSpan.getSpanContext().getSpanId(), exception.getClass().getSimpleName());
            }
        } catch (Exception e) {
            logger.warn("Failed to record exception on span: {}", e.getMessage());
        }
    }
    
    /**
     * Record a custom error event on the current span
     * 
     * @param eventName Name of the error event
     * @param errorMessage Error message
     * @param attributes Additional attributes for the error event
     */
    public static void recordErrorEvent(String eventName, String errorMessage, Attributes attributes) {
        try {
            Span currentSpan = Span.current();
            
            if (currentSpan != null && currentSpan.getSpanContext().isValid()) {
                // Set span status to error
                currentSpan.setStatus(StatusCode.ERROR, errorMessage);
                
                // Add custom error event
                currentSpan.addEvent(eventName, 
                    Attributes.of(
                        AttributeKey.stringKey("error.message"), errorMessage,
                        AttributeKey.stringKey("error.type"), "CUSTOM_ERROR"
                    ));
                
                logger.debug("Recorded error event '{}' on span: {}", eventName, currentSpan.getSpanContext().getSpanId());
            }
        } catch (Exception e) {
            logger.warn("Failed to record error event on span: {}", e.getMessage());
        }
    }
} 