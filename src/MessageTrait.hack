/**
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * This software consists of voluntary contributions made by many individuals
 * and is licensed under the MIT license.
 *
 * Copyright (c) 2018-2019 Yuuki Takezawa
 *
 */

namespace Ytake\Hungrr;

use namespace HH\Lib\{C, Dict, Regex, Str, Vec};

trait MessageTrait {

  private dict<string, vec<string>> $headers = dict[];
  private dict<string, string> $headerNames = dict[];

  private string $protocol = '1.1';

  protected function extractHeaders(string $header, vec<string> $value): void {
    $nh = $this->lowHeader($header);
    if (C\contains_key($this->headerNames, $nh)) {
      $header = $this->headerNames[$nh];
      $this->headers[$header] =  Vec\concat($this->headers[$header], $value);
      return;
    }
    $this->headerNames[$nh] = $header;
    $this->headers[$header] = $value;
  }

  private function setHeaders(dict<string, vec<string>> $originalHeaders): void {
    foreach ($originalHeaders as $header => $value) {
      $this->assertHeader($header);
      $this->extractHeaders(
        $header,
        $this->filterHeaderValue($this->validateAndTrimHeader($header, $value))
      );
    }
  }

  private function assertHeader(string $name): void {
    AssertHeader::assertValidName($name);
  }

  private function filterHeaderValue(vec<string> $values): vec<string> {
    if (!C\count($values)) {
      throw new Exception\InvalidArgumentException(
        'Invalid header value: must be a vec<string>; cannot be an empty vec[]'
      );
    }
    return Vec\map($values, ($t) ==> {
      AssertHeader::assertValid($t);
      return Str\trim($t, " \t");
    });
  }

  <<__Rx>>
  public function getProtocolVersion(): string {
    return $this->protocol;
  }

  public function withProtocolVersion(string $version): this {
    if ($this->protocol === $version) {
      return $this;
    }
    $new = clone $this;
    $new->protocol = $version;
    return $new;
  }

  <<__Rx>>
  public function getHeaders(): dict<string, vec<string>> {
    return $this->headers;
  }

  public function hasHeader(string $header): bool {
    return C\contains_key($this->headerNames, $this->lowHeader($header));
  }

  public function getHeader(string $header): vec<string> {
    $lowHeader = $this->lowHeader($header);
    if (!C\contains_key($this->headerNames, $lowHeader)) {
      return vec[];
    }
    return $this->headers[$this->headerNames[$lowHeader]];
  }

  public function getHeaderLine(string $header): string {
    return Str\join($this->getHeader($header), ', ');
  }

  public function withHeader(string $header, vec<string> $value): this {
    $lowHeader = $this->lowHeader($header);
    $new = clone $this;
    if (C\contains_key($this->headerNames, $lowHeader)) {
      $new->headers = Dict\filter_keys(
        $new->headers,
        ($k) ==> $k !== $this->headerNames[$lowHeader]
      );
    }
    $new->headerNames[$lowHeader] = $header;
    $new->headers[$header] = $this->filterHeaderValue($this->validateAndTrimHeader($header, $value));
    return $new;
  }

  public function withHeaderLine(string $name, string $value): this {
    return $this->withHeader($name, Str\split($value, ','));
  }

  public function withAddedHeader(string $name, vec<string> $value): this {
    if ('' === $name) {
      throw new \InvalidArgumentException('Header name must be an RFC 7230 compatible string.');
    }
    $new = clone $this;
    $new->setHeaders(dict[$name => $value]);
    return $new;
  }

  public function withAddedHeaderLine(string $name, string $value): this {
    return $this->withAddedHeader($name, Str\split($value, ','));
  }

  public function withoutHeader(string $header): this {
    $lowHeader = $this->lowHeader($header);
    if (!C\contains_key($this->headerNames, $lowHeader)) {
      return $this;
    }
    $header = $this->headerNames[$lowHeader];
    $new = clone $this;
    $new->headers = Dict\filter_keys($new->headers, ($k) ==> $k !== $header);
    $new->headerNames = Dict\filter_keys($new->headerNames, ($k) ==> $k !== $lowHeader);
    return $new;
  }

  private function validateAndTrimHeader(string $header, vec<string> $values): vec<string> {
    if (!Regex\matches($header, re"@^[!#$%&'*+.^_`|~0-9A-Za-z-]+$@")) {
      throw new Exception\InvalidArgumentException('Header name must be an RFC 7230 compatible string.');
    }
    return Vec\map($values, ($r) ==> {
      if (!Regex\matches($r, re"@^[ \t\x21-\x7E\x80-\xFF]*$@")) {
        throw new \InvalidArgumentException('Header values must be RFC 7230 compatible string.');
      }
      return Str\trim($r, " \t");
    });
  }

  <<__Memoize>>
  private function lowHeader(string $header): string {
    return Str\lowercase($header);
  }
}
