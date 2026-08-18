package misarblog

import (
	"bytes"
	"mime/multipart"
)

// buildMultipart builds a multipart/form-data body with a single file field.
// Returns the encoded body, the Content-Type header (with boundary), and any error.
func buildMultipart(field, filename string, data []byte) ([]byte, string, error) {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	part, err := w.CreateFormFile(field, filename)
	if err != nil {
		return nil, "", err
	}
	if _, err := part.Write(data); err != nil {
		return nil, "", err
	}
	if err := w.Close(); err != nil {
		return nil, "", err
	}
	return buf.Bytes(), w.FormDataContentType(), nil
}
